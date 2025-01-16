#!/bin/bash

## ElasticSearch benchmark on Amazon Linux 2023, i8g.2xlarge

# 查询所有需要挂载的本地盘
DISKS=$(lsblk -n -o NAME,TYPE,PTTYPE,PARTTYPE --list | grep disk | grep -v gpt | awk -F" " '{print $1}')
echo $DISKS

# 挂载数据盘
for disk in $DISKS
do
	echo "[INFO] Start to handle $disk..."
	# 格式化磁盘
	DEVICE=/dev/$disk
	mkfs -t xfs $DEVICE
	UUID=$(blkid | grep $disk| awk -F "\"" '{print $2}')
	
	# 创建挂载目录
	MOUNTDIR="/mnt/$disk"
	mkdir -p $MOUNTDIR
	
	# fstab 添加表项
	echo "UUID=$UUID $MOUNTDIR xfs  defaults,nofail  0  2" >> /etc/fstab
done
# cat /etc/fstab
mount -a && df -h

## 设置一些系统参数
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 131072" >> /etc/security/limits.conf
echo "* soft nproc 4096" >> /etc/security/limits.conf
echo "* hard nproc 4096" >> /etc/security/limits.conf
echo "vm.max_map_count=262145" >> /etc/sysctl.conf
sysctl -p 
echo always > /sys/kernel/mm/transparent_hugepage/enabled
echo always > /sys/kernel/mm/transparent_hugepage/defrag

# ElasticSearch 安装信息
VERSION="7.13.4"
esuser="ec2-user"
IPADDR="127.0.0.1"
NODENAME=node-$RANDOM
ESROOTDISK="/mnt/nvme1n1"   ## for i4g/i4i/i7ie/i8g
# ESROOTDISK="/mnt/nvme0n1" ## for i3
# ESROOTDISK="/home/$esuser"

# 安装目录
cd /root/
ARCH=$(arch)
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${VERSION}-linux-${ARCH}.tar.gz
tar zxf elasticsearch-${VERSION}-linux-${ARCH}.tar.gz
mv elasticsearch-${VERSION} $ESROOTDISK/elasticsearch
mkdir -p $ESROOTDISK/elasticsearch/data
mkdir -p $ESROOTDISK/elasticsearch/logs
chown -R $esuser:$esuser $ESROOTDISK/elasticsearch

## 生成 ES 配置文件
cat << EOF > $ESROOTDISK/elasticsearch/config/elasticsearch.yml
bootstrap.memory_lock: false
bootstrap.system_call_filter: true
cluster.name: es-cluster
cluster.initial_master_nodes: ["${IPADDR}"]
cluster.routing.allocation.same_shard.host: true 
discovery.seed_hosts: ["${IPADDR}"]
discovery.zen.ping_timeout: 90s
discovery.zen.fd.ping_interval: 10s
discovery.zen.fd.ping_timeout: 120s 
discovery.zen.fd.ping_retries: 12
network.host: ${IPADDR}
network.bind_host: ${IPADDR}
network.publish_host: ${IPADDR}
node.name: ${NODENAME}
node.master: true
node.data: true
http.port: 9200
path.data: $ESROOTDISK/elasticsearch/data 
path.logs: $ESROOTDISK/elasticsearch/logs
indices.query.bool.max_clause_count : 2048 
indices.memory.index_buffer_size: 30% 
indices.fielddata.cache.size: 40%
indices.breaker.fielddata.limit: 70%
indices.recovery.max_bytes_per_sec: 20mb 
indices.breaker.total.use_real_memory: false
thread_pool.write.queue_size: 1000
action.auto_create_index: .monitoring*,.watches,.triggered_watches,.watcher-history*,.ml*
EOF

# 启动 
su ${esuser} -c "$ESROOTDISK/elasticsearch/bin/elasticsearch -d -p pid"
echo "[$(date)] Wait for ElasticSearch start successfully."
sleep 10
curl -XGET http://$IPADDR:9200/_cat/health?v

######## 安装ESRally ######## 
mkdir -p $ESROOTDISK/esrally_benchmark /root/.rally 
ln -s $ESROOTDISK/esrally_benchmark /root/.rally/benchmarks

yum install -y python3-pip python3-devel git gcc gcc-c++ htop
pip3 install dool
pip3 install esrally --ignore-installed requests
pip3 install pytrec_eval==0.5 numpy==1.24.0 --upgrade --target /root/.rally/libs

mkdir -p /root/.rally/benchmarks/tracks 
cd /root/.rally/benchmarks/tracks 
git clone https://github.com/elastic/rally-tracks.git

# 安装pbzip2，多线程解压缩工具
cd /root/
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(arch).sh
bash Miniconda3-latest-Linux-$(arch).sh -b -p /root/miniconda3/
eval "$(/root/miniconda3/bin/conda shell.bash hook)"
conda init
source /root/.bashrc
conda config --add channels conda-forge
conda config --set channel_priority strict
conda install -y pbzip2
ln -s /root/miniconda3/bin/pbzip2  /usr/bin/pbzip2

cd /root/
vi benchmark.sh
################################################################################
#!/bin/bash
# IPADDR=${1}
# INSTANCE_TYPE=${2}
tracks=${1}

# esrally on localhost
IPADDR="127.0.0.1"
INSTANCE_TYPE=$(cloud-init query ds.meta_data.instance_type)

# tracks="nested noaa sql pmc http_logs so_vector so geoshape wikipedia k8s_metrics openai_vector github_archive eql"

for i in ${tracks}
do
    ttt=$(date +%Y%m%d%H%M%S)
    RACE_ID=esrally-${INSTANCE_TYPE}-${i}-${ttt}
    esrally race --track-repository=rally-tracks --track=${i} \
      --pipeline=benchmark-only --race-id=${RACE_ID} \
      --target-hosts=http://${IPADDR}:9200 \
      > ${RACE_ID}.log
done
#######

nohup bash benchmark.sh &


###################
# reboot 后启动
VERSION="7.13.4"
esuser="ec2-user"
IPADDR="127.0.0.1"
ESROOTDISK="/mnt/nvme1n1" 
# ESROOTDISK="/mnt/nvme0n1" 
su ${esuser} -c "$ESROOTDISK/elasticsearch/bin/elasticsearch -d -p pid"
echo "[$(date)] Wait for ElasticSearch start successfully."
sleep 30
curl -XGET http://$IPADDR:9200/_cat/health?v
nohup bash benchmark.sh &


## 停止并清理数据：先停止其他节点，最后停止 master节点
# kill -9 $(cat /home/${esuser}/elasticsearch/pid)
# rm -rf /home/${esuser}/elasticsearch/data

# IPADDR=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | awk -F " " '{print $2}')
# IPADDR=$(hostname -i)