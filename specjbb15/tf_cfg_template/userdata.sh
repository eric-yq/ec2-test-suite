#!/bin/bash

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

    ### 如果 3 分钟之后，实例没有重启，或者也有可能不需要重启，则开始启动服务执行后续安装过程。
    sleep 180
    systemctl start userdata.service
    exit 0
fi

############## 

if [[ X"$1" == X"" ]]; then
	let THREADS_PROBE=64
else
	let THREADS_PROBE=${1}
fi

## 配置 AWSCLI
aws_ak_value="akxxx"
aws_sk_value="skxxx"
aws_region_name="us-west-2"
aws configure set aws_access_key_id ${aws_ak_value}
aws configure set aws_secret_access_key ${aws_sk_value}
aws configure set default.region ${aws_region_name}
aws_s3_bucket_name="s3://ec2-core-benchmark-ericyq"

## 安装 Java
yum update -y

# ## Corretto 11 --default
yum install -y java-11-amazon-corretto
JDK_VERSION='corretto11'

## Corretto 17
# yum install java-17-amazon-corretto -y
# JDK_VERSION='corretto17'

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

## alibaba dragonwell 11
# yum install -y java-11-alibaba-dragonwell
# JDK_VERSION='dragonwell11'

java -version
yum install -y htop dmidecode python3-pip
pip3 install dool

## 系统配置
PN=$(cloud-init query ds.meta_data.instance_type)
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

## 下载安装包
cd /root/
aws s3 cp ${aws_s3_bucket_name}/software/specjbb2015-1.02.tar.gz .
tar -xzf specjbb2015-1.02.tar.gz

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


## 执行 Benchmark
RESULT_SUMMARY_FILE="/root/specjbb/specjbb_results.txt"
mkdir -p /root/specjbb
echo "Star to run specjbb15 benchmark on ${PN}." >> ${RESULT_SUMMARY_FILE}
echo "JAVA VERSION is: ${JDK_VERSION}." >> ${RESULT_SUMMARY_FILE}
echo "Instance Type: ${PN}, ${CPU_CORES} vCPU, Memory ${MEM_TOTAL_MB} MB." >> ${RESULT_SUMMARY_FILE}
echo "XMS=${XMS}, XMX=${XMX}, XMN=${XMN}, ParallelGCThreads=${GC_THREADS}, workers.Tier1=${WORKERS_TIER1}, workers.Tier3=${WORKERS_TIER3}" >> ${RESULT_SUMMARY_FILE}
echo "THREADS_PROBE=${THREADS_PROBE}" >> ${RESULT_SUMMARY_FILE}

## 启动 dstat 监控
# DSTAT_LOGFILE="/root/specjbb/dstat.log"
# echo "Testcase: THREADS_PROBE=${THREADS_PROBE}......"
# nohup dstat -cmndryt 60 > $DSTAT_LOGFILE 2>&1 & echo $! > pid_file.txt
# # kill -9 $(cat pid_file.txt)

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

# 停止 dstat
# kill -9 $(cat pid_file.txt)

## 保存结果并上传到 S3 bucket
cd /root/
grep "RUN RESULT: hbIR" ~/specjbb/composite.out >> ${RESULT_SUMMARY_FILE}
cp -r result specjbb/
DATATIME=$(date +%Y%m%d%H%M%S)
tar czf specjbb15-${JDK_VERSION}-${PN}-${DATATIME}.tar.gz specjbb/
aws s3 cp sspecjbb15-${JDK_VERSION}-${PN}-${DATATIME}.tar.gz ${aws_s3_bucket_name}/result_specjbb15/
aws s3 ls ${aws_s3_bucket_name}
echo "Upload specjbb15-${JDK_VERSION}-${PN}-${DATATIME}.tar.gz to ${aws_s3_bucket_name} ."

sleep 30
# 终止实例
INSTANCE_ID=$(ls /var/lib/cloud/instances/)
aws ec2 stop-instances --instance-ids "${INSTANCE_ID}" --region $(cloud-init query region)
