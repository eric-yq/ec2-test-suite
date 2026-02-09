# @@@ 这是一台 AeroLab 所在实例
# c7g.4xlarge, Amazon Linux 2023

# 配置AWS CLI
aws --version
## AWSCLI 配置：Global
aws_sk_value="xxx"
aws_sk_value="xxx"
aws_region_name=$(ec2-metadata --quiet --region)
aws configure set aws_access_key_id ${aws_ak_value}
aws configure set aws_secret_access_key ${aws_sk_value}
aws configure set default.region ${aws_region_name}
aws s3 ls

# 安装aerolab
cd /root/
wget https://github.com/aerospike/aerolab/releases/download/7.7.1/aerolab-linux-arm64-7.7.1.zip
unzip aerolab-linux-arm64-7.7.1.zip -d /usr/local/bin/
aerolab version
aerolab completion bash
source ~/.bashrc


##########################################################################################
# aerospike.conf 模板
mkdir -p /root/aerospike-conf-samples
#### aerospike.conf： 数据仅在内存中
cat > /root/aerospike-conf-samples/memory-only.conf << EOF
namespace test {
    storage-engine memory {
        data-size 48G                 # memory pre-allocated for the data of this namespace
    }
}
EOF
#### aerospike.conf： 数据在内存中，持久化到磁盘文件
cat > /root/aerospike-conf-samples/memory-and-file.conf << EOF
namespace test {
    storage-engine memory {
        file /opt/aerospike/data/test.dat   # location of a namespace data file on server
        filesize 48G                  # maximum size of each file in GiB; maximum size is 2TiB
    }
}
EOF
#### aerospike.conf： 数据磁盘文件中 /// 测试中............
cat > /root/aerospike-conf-samples/device-and-file.conf << EOF
network {
    service {
        address any
        port 3000
    }
    fabric {
        port 3001
    }
}
namespace test {
    default-ttl 0
    index-stage-size 1G
    replication-factor 2
    sindex-stage-size 1G
    storage-engine device {
        file /opt/aerospike/data/test.dat
        filesize 48G
    }
}
EOF


# AeroSpike 集群公共配置
# 获取子网 ID和安全组 ID
INSTANCE_ID=$(ec2-metadata --quiet --instance-id)
REGION=$(ec2-metadata --quiet --region)
SGID=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --region $REGION \
  --query 'Reservations[0].Instances[0].SubnetId' \
  --output text)
SUBID=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --region $REGION \
  --query 'Reservations[0].Instances[0].SecurityGroups[*].GroupId' \
  --output text)


## AWS EC2 实例配置
INSTYPE="r6id.8xlarge"
COUNT=3
INSFAMILY=$(echo $INSTYPE | cut -d'.' -f1)
NAME="cluster_$INSFAMILY"
DISKS="type=gp3,size=80"
DISTRO="amazon"
DISTROVERSION="2023"
INSARCH=$(aws ec2 describe-instance-types \
  --instance-types $INSTYPE \
  --query "InstanceTypes[0].ProcessorInfo.SupportedArchitectures" \
  --output text)
AMIID=$(aws ssm get-parameter \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-$INSARCH \
  --region $REGION --query Parameter.Value --output text)
echo $REGION $MAC $SGID $SUBID $AMIID
## Aerospike 配置
VERSION="7.2.0.8c"
# CONF="/root/aerospike-conf-samples/device-and-nvme.conf"

## 创建集群
aerolab config backend -t aws -p /root/.aerolab -r $REGION
aerolab cluster create \
  --name $NAME \
  --count $COUNT \
  --instance-type $INSTYPE \
  --ami $AMIID \
  --aws-disk $DISKS \
  --secgroup-id $SGID \
  --subnet-id $SUBID \
  --distro $DISTRO --distro-version $DISTROVERSION \
  --aerospike-version $VERSION \
  --aws-expire 0 \
  --start n \
#   --aws-spot-instance \
#   --customconf $CONF \
  
## 本地盘实例单独处理：
## https://github.com/aerospike/aerolab/blob/bc9873cf0da8cd0d3d23f9907ab88ef142f8f453/docs/partitioner/all-nvme-disks-memory.md
aerolab cluster partition list --name $NAME
aerolab cluster partition create --name $NAME --filter-type=nvme
aerolab cluster partition conf   --name $NAME --filter-type=nvme \
  --namespace=test \
  --filter-partitions=0 \
  --configure=memory

## 启动集群
aerolab aerospike stop    --name $NAME
aerolab aerospike start   --name $NAME
aerolab aerospike restart --name $NAME

## 查看状态
aerolab attach shell   --name $NAME -- asadm -e info
aerolab inventory list

## SSH 连接到某个节点，可以远程执行命令
aerolab attach shell --name $NAME -- asinfo -v "service"
aerolab attach shell --name $NAME -- aql
aerolab attach shell --name $NAME --node=all -- "yum install -yq htop python3-pip && pip3 install dool"
aerolab attach shell --name=$NAME --node=1 -- "dool -cmndryt 10"
aerolab attach shell --name=$NAME --node=2 -- "dool -cmndryt 10"
aerolab attach shell --name=$NAME --node=3 -- "dool -cmndryt 10"
  
## 释放集群
aerolab cluster destroy --force --name $NAME 

##########################################################################################
# 安装 AeroSpike Tools
cd /root
wget https://download.aerospike.com/artifacts/aerospike-tools/11.2.0/aerospike-tools_11.2.0_amzn2023_aarch64.tgz
tar zxf aerospike-tools_11.2.0_amzn2023_aarch64.tgz 
cd aerospike-tools_11.2.0_amzn2023_aarch64/
./asinstall


##########################################################################################
# 使用 YCSB进行测试，依赖python2.7
sudo dnf update -y
sudo dnf groupinstall "Development Tools" -y
sudo dnf install openssl-devel bzip2-devel libffi-devel -y
cd /opt
sudo wget https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tgz
sudo tar xzf Python-2.7.18.tgz
cd Python-2.7.18
sudo ./configure --enable-optimizations
sudo make altinstall
sudo ln -s /usr/local/bin/python2.7 /usr/local/bin/python

cd /root/
wget https://github.com/brianfrankcooper/YCSB/releases/download/0.17.0/ycsb-aerospike-binding-0.17.0.tar.gz
tar zxf ycsb-aerospike-binding-0.17.0.tar.gz
ln -s /root/ycsb-aerospike-binding-0.17.0/bin/ycsb /usr/local/bin/ycsb
ycsb -h

## 生成 workload 文件
cat > /root/ycsb-aerospike-binding-0.17.0/workloads/test_1K_1M << EOF
recordcount=1000000
operationcount=1000000
workload=site.ycsb.workloads.CoreWorkload
readallfields=true
readproportion=0.5
updateproportion=0.5
scanproportion=0
insertproportion=0
readmodifywriteproportion=0
requestdistribution=uniform
insertorder=hashed
fieldlength=100
fieldcount=10
EOF
cat > /root/ycsb-aerospike-binding-0.17.0/workloads/test_1K_100M << EOF
recordcount=100000000
operationcount=100000000
workload=site.ycsb.workloads.CoreWorkload
readallfields=true
readproportion=0.5
updateproportion=0.5
scanproportion=0
insertproportion=0
readmodifywriteproportion=0
requestdistribution=uniform
insertorder=hashed
fieldlength=100
fieldcount=10
EOF
cat > /root/ycsb-aerospike-binding-0.17.0/workloads/test_2K_10M << EOF
recordcount=10000000
operationcount=10000000
workload=site.ycsb.workloads.CoreWorkload
readallfields=true
readproportion=0.5
updateproportion=0.5
scanproportion=0
insertproportion=0
readmodifywriteproportion=0
requestdistribution=uniform
insertorder=hashed
fieldlength=100
fieldcount=20
EOF
cat > /root/ycsb-aerospike-binding-0.17.0/workloads/test_2K_100M << EOF
recordcount=100000000
operationcount=100000000
workload=site.ycsb.workloads.CoreWorkload
readallfields=true
readproportion=0.5
updateproportion=0.5
scanproportion=0
insertproportion=0
readmodifywriteproportion=0
requestdistribution=uniform
insertorder=hashed
fieldlength=100
fieldcount=20
EOF

# load data
IPADDR=$(aerolab attach shell --name $NAME -- hostname -I | tr -d ' ')
cd /root/ycsb-aerospike-binding-0.17.0/
mkdir -p results
RESULT_FILE=/root/ycsb-aerospike-binding-0.17.0/results/$NAME-ycsb-load.txt
RESULT_FILE1=/root/ycsb-aerospike-binding-0.17.0/results/$NAME-ycsb-run.txt
echo "[Info] Load data ..." >> ${RESULT_FILE}
bin/ycsb load aerospike -s \
  -P workloads/test_2K_100M \
  -p as.host=$IPADDR  \
  -p as.namespace=test \
  -threads 128  >> ${RESULT_FILE}

# run benchmark
THREADS="128 256 384 512 640 768 1024"
for i in $THREADS
do
    echo "[Info] Run benchmark ..." >> ${RESULT_FILE1}
    bin/ycsb  run aerospike  -s \
		-P workloads/test_2K_100M \
		-p as.host=172.31.38.190 \
		-p as.namespace=test \
		-p aerospike.timeout=2000 \
		-p aerospike.maxRetries=3 \
		-p aerospike.sleepBetweenRetries=100 \
		-threads 256   >> ${RESULT_FILE1}
		
	sleep 10
done


            

# 参考文档
https://aerospike.com/blog/comparing-nosql-databases-aerospike-vs-cassandra-benchmarking-for-real/
https://github.com/aerospike-examples/aerospike-benchmarks/
https://aerospike.com/files/white-papers/running-operational-workloads-aerospike-petabyte-scale-cloud-20-nodes-whitepaper.pdf
https://aerospike.com/files/white-papers/aws-graviton-benchmark-whitepaper.pdf





##########################################################################################
# 安装 asbench 工具
yum groupinstall -y "Development Tools"
yum install -y openssl-devel libyaml-devel libevent-devel cmake python3-pip
pip3 install dool
cd /root
git clone https://github.com/aerospike/aerospike-benchmark.git
cd aerospike-benchmark
#### 修改 .gitmodule 中内容
sed -i.bak "s/git@github.com:/https:\/\/github.com\//g" .gitmodules 
git submodule sync
git submodule update --init --recursive
make EVENT_LIB=libevent -j
ln -s target/asbench  /usr/local/bin/asbench
asbench -v

##########################################################################################
# 执行Benchmark
IPADDR=$(aerolab attach shell --name $NAME -- hostname -I) && echo $IPADDR

## 插入数据
# asbench --hosts $IPADDR \
#   --namespace test --set benchset --bin testbin \
#   --workload I --start-key 0 --keys 10000000 --object-spec S16,i \
#   --threads 64 --duration 0 \
#   --socket-timeout 200 --timeout 1000 \
#   --read-mode-sc allowReplica --max-retries 2  \
#   --latency 
## 执行
# asbench -h $IPADDR --workload RU,50 --duration 300 --threads 64


##########################################################################################
# 安装集群监控组件
# 为集群节点安装exporter
aerolab cluster add exporter -n $NAME

# 创建 Monitor stack
# 获取子网 ID和安全组 ID
INSTANCE_ID=$(ec2-metadata --quiet --instance-id)
REGION=$(ec2-metadata --quiet --region)
SGID=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --region $REGION \
  --query 'Reservations[0].Instances[0].SubnetId' \
  --output text)
SUBID=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --region $REGION \
  --query 'Reservations[0].Instances[0].SecurityGroups[*].GroupId' \
  --output text)
# echo $REGION $MAC $SGID $SUBID
INSTYPE="c6g.xlarge"
NAME="ams"
DISKS="type=gp3,size=40"
INSARCH=$(aws ec2 describe-instance-types \
  --instance-types $INSTYPE \
  --query "InstanceTypes[0].ProcessorInfo.SupportedArchitectures" \
  --output text)
AMIID=$(aws ssm get-parameter \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-$INSARCH \
  --region $REGION --query Parameter.Value --output text)
echo $REGION $MAC $SGID $SUBID $AMIID 
CLUSTERS="cluster_c6i,cluster_c7g,cluster_c8g"
aerolab client create ams \
  --group-name $NAME \
  --clusters $CLUSTERS \
  --instance-type $INSTYPE \
  --aws-disk $DISKS \
  --secgroup-id $SGID \
  --subnet-id $SUBID \
  --public-ip 

## 查看 Client 清单
aerolab inventory list
aerolab client list
## 通过 AccessURL 访问网页，默认用户名/密码： admin/admin

## 新建了 AeroSpike 集群，则可以向 ams 中 append 新集群，作为monitor 的source
aerolab client configure ams --group-name ams --clusters "cluster_c6i,cluster_c7g,cluster_c8g"


