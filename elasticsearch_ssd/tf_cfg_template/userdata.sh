#!/bin/bash

## 暂时关闭补丁更新流程
sudo systemctl stop amazon-ssm-agent
sudo systemctl disable amazon-ssm-agent

# 实例启动成功之后的首次启动 OS， /root/userdata.sh 不存在，创建该 userdata.sh 文件并设置开启自动执行该脚本。
if [ ! -f "/root/userdata.sh" ]; then
    echo "首次启动 OS, 未找到 /root/userdata.sh，准备创建..."
    # 复制文件
    cp /var/lib/cloud/instance/scripts/part-001 /root/userdata.sh
    chmod +x /root/userdata.sh
    # 创建 systemd 服务单元
    cat > /etc/systemd/system/userdata.service << EOF
[Unit]
Description=Execute userdata script at boot
After=network.target

[Service]
Type=oneshot
User=root
ExecStart=/root/userdata.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    # 启用服务
    systemctl daemon-reload
    systemctl enable userdata.service
    
    echo "已创建并启用 systemd 服务 userdata.service"

    ### 等待 180 秒再执行 userdata 脚本
    sleep 180
    systemctl start userdata.service
    exit 0
fi

################################################################################################################ 

SUT_NAME="SUT_PTS_SSD"

# 配置 AWSCLI
cd /root/
yum remove -y awscli
ARCH=$(arch)
curl "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
cp -rf /usr/local/bin/aws /usr/bin/aws
aws --version

aws_ak_value="akxxx"
aws_sk_value="skxxx"
aws_region_name=$(ec2-metadata --quiet --region)
aws configure set aws_access_key_id ${aws_ak_value}
aws configure set aws_secret_access_key ${aws_sk_value}
aws configure set default.region ${aws_region_name}
aws_s3_bucket_name=$(aws s3 ls | awk '{print $3}' | grep ec2-core-benchmark | head -1)

# 设置磁盘lvm stripe
cd /root/
yum install -yq git
git clone https://github.com/eric-yq/ec2-test-suite.git
bash ec2-test-suite/tools/setup_nvme_instance_store.sh
# 如果有本地盘，脚本执行后挂载到 /data；如果没有本地盘，则脚本退出。


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
VERSION="8.19.22"
esuser="ec2-user"
IPADDR="$(hostname -i)"
NODENAME=node-$RANDOM
ESROOTDISK="/data"  

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



## 停止并清理数据：先停止其他节点，最后停止 master节点
# kill -9 $(cat /home/${esuser}/elasticsearch/pid)
# rm -rf /home/${esuser}/elasticsearch/data

# IPADDR=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | awk -F " " '{print $2}')
# IPADDR=$(hostname -i)


## Disable 服务，这样 reboot 后不会再次执行
systemctl disable userdata.service