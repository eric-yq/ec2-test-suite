#!/bin/bash

yum update -y
yum install -y unzip screen

## 配置 AWSCLI
cd /root/
yum remove -y awscli
ARCH=$(arch)
curl "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
cp -rf /usr/local/bin/aws /usr/bin/aws
aws --version

aws_ak_value="xxx"
aws_sk_value="+xxx"
aws_region_name="us-east-2"
aws configure set aws_access_key_id ${aws_ak_value}
aws configure set aws_secret_access_key ${aws_sk_value}
aws configure set default.region ${aws_region_name}


## 下载安装包
cd /root/
aws s3 cp ${aws_s3_bucket_name}/software/specjbb2015-1.02.tar.gz .
tar -xzf specjbb2015-1.02.tar.gz

## 安装 Java

# ## Corretto 11 --default
# yum install -y java-11-amazon-corretto
# JDK_VERSION='corretto11'

# JDK 1.8
# yum install -y java-1.8.0-openjdk
# JDK_VERSION='openjdk8'

## JDK 1.11
# amazon-linux-extras install  -y java-openjdk11
# JDK_VERSION='openjdk11'

## JDK 1.17
# wget wget https://download.oracle.com/java/17/latest/jdk-17_linux-x64_bin.rpm
# wget https://download.oracle.com/java/17/latest/jdk-17_linux-aarch64_bin.rpm
# yum install -y ./*.rpm
# JDK_VERSION='openjdk17'

screen -R ttt -L

# alibaba dragonwell 11
yum install -y java-11-alibaba-dragonwell htop dmidecode
JDK_VERSION='dragonwell11'
java -version

## 系统配置
PN=$(cloud-init query ds.meta-data.instance.instance-type)
cat << EOF >> /etc/sysctl.conf
dev.raid.speed_limit_min = 4000
kernel.sched_rt_runtime_us = 990000
kernel.shmall = 64562836
net.core.netdev_max_backlog = 2048
net.core.rmem_default = 106496
net.core.rmem_max = 4194304
net.core.somaxconn = 2048
net.core.wmem_default = 65536
net.core.wmem_max = 8388608
net.ipv4.tcp_adv_win_scale = 0
net.ipv4.tcp_fin_timeout = 40
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_rmem = 4096 98304 196608
net.ipv4.tcp_sack = 0
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_window_scaling = 0
net.ipv4.tcp_wmem = 4096 131072 8388608
vm.dirty_background_ratio = 15
vm.dirty_expire_centisecs = 10000
vm.dirty_ratio = 8
vm.dirty_writeback_centisecs = 1500
vm.swappiness = 0
vm.zone_reclaim_mode = 1
EOF

sysctl -p
echo always > /sys/kernel/mm/transparent_hugepage/enabled

## 获取 CPU数 和 内存数量（KB）
CPU_CORES=$(nproc)
MEM_TOTAL_MB=$(free -m |grep Mem | awk -F " " '{print $2}')

## 变量计算
let XMS=${MEM_TOTAL_MB}*90/100
let XMX=${MEM_TOTAL_MB}*90/100
let XMN=${MEM_TOTAL_MB}*80/100
let GC_THREADS=${CPU_CORES}
let WORKERS_TIER1=${CPU_CORES}
let WORKERS_TIER3=${CPU_CORES}/4

THREADS_PROBE=64

## 执行 Benchmark
RESULT_SUMMARY_FILE="/root/specjbb/specjbb_results.txt"
mkdir -p /root/specjbb
echo "Star to run specjbb15 benchmark on ${PN}." >> ${RESULT_SUMMARY_FILE}
echo "JAVA VERSION is: ${JDK_VERSION}." >> ${RESULT_SUMMARY_FILE}
echo "Instance Type: ${PN}, ${CPU_CORES} vCPU, Memory ${MEM_TOTAL_MB} MB." >> ${RESULT_SUMMARY_FILE}
echo "XMS=${XMS}, XMX=${XMX}, XMN=${XMN}, ParallelGCThreads=${GC_THREADS}, workers.Tier1=${WORKERS_TIER1}, workers.Tier3=${WORKERS_TIER3}" >> ${RESULT_SUMMARY_FILE}
echo "THREADS_PROBE=${THREADS_PROBE}" >> ${RESULT_SUMMARY_FILE}

java -showversion -server \
-Xms${XMS}m \
-Xmx${XMX}m \
-Xmn${XMN}m \
-XX:SurvivorRatio=20 \
-XX:MaxTenuringThreshold=15 \
-XX:+UseLargePages \
-XX:LargePageSizeInBytes=2m \
-XX:+UseParallelGC \
-XX:+AlwaysPreTouch \
-XX:-UseAdaptiveSizePolicy \
-XX:-UsePerfData \
-XX:ParallelGCThreads=${GC_THREADS} \
-XX:+UseTransparentHugePages \
-XX:+UseCompressedOops \
-XX:ObjectAlignmentInBytes=32 \
-Dspecjbb.comm.connect.timeouts.connect=700000 \
-Dspecjbb.comm.connect.timeouts.read=700000 \
-Dspecjbb.comm.connect.timeouts.write=700000 \
-Dspecjbb.customerDriver.threads.probe=${THREADS_PROBE} \
-Dspecjbb.forkjoin.workers.Tier1=${WORKERS_TIER1} \
-Dspecjbb.forkjoin.workers.Tier2=1 \
-Dspecjbb.forkjoin.workers.Tier3=${WORKERS_TIER3} \
-Dspecjbb.heartbeat.period=100000 \
-Dspecjbb.heartbeat.threshold=1000000 \
-jar ./specjbb2015.jar -m COMPOSITE \
2> ./specjbb/composite.log > ./specjbb/composite.out

sleep 60

## 保存结果并上传到 S3 bucket
aws_s3_bucket_name="s3://ec2-core-benchmark-ericyq"
cd /root/
grep "RUN RESULT: hbIR" ~/specjbb/composite.out >> ${RESULT_SUMMARY_FILE}
cp -r result specjbb/
tar czf specjbb15-${JDK_VERSION}-${PN}.tar.gz specjbb/
aws s3 cp specjbb15-${JDK_VERSION}-${PN}.tar.gz ${aws_s3_bucket_name}/result_specjbb15/
aws s3 ls ${aws_s3_bucket_name}
echo "Upload specjbb15-${JDK_VERSION}-${PN}.tar.gz to ${aws_s3_bucket_name} ."

# sleep 30
# 
# ## 终止实例
# INSTANCE_ID=$(ls /var/lib/cloud/instances/)
# aws ec2 stop-instances --instance-ids "${INSTANCE_ID}"
