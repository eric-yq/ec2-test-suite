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

    ### 等待 60 秒再执行 userdata 脚本
    sleep 60
    systemctl start userdata.service
    exit 0
fi

################################################################################################################ 

SUT_NAME="SUT_XXX"

## 配置 AWSCLI
aws_ak_value="akxxx"
aws_sk_value="skxxx"
aws_region_name=$(cloud-init query region)
aws configure set aws_access_key_id ${aws_ak_value}
aws configure set aws_secret_access_key ${aws_sk_value}
aws configure set default.region ${aws_region_name}
aws_s3_bucket_name="s3://ec2-core-benchmark-ericyq"

yum update -y

## 安装所有 Corretto 版本
yum install -yq java-1.8.0-amazon-corretto-devel \
  java-11-amazon-corretto-devel \
  java-17-amazon-corretto-devel \
  java-21-amazon-corretto-devel

## 设置默认 JDK 版本为 Corretto 17
if [[ X"$1" == X"" ]]; then
	version=17
else
	version=${1}
fi
if [[ ! "$version" =~ ^(8|11|17|21)$ ]]; then
    echo "错误: 不支持的版本号 '$version'"
    echo "用法: install_and_switch_corretto <8|11|17|21>"
    return 1
fi
case $version in
    8)
        JDK_VERSION="corretto8"
        JAVA_PATH="/usr/lib/jvm/java-1.8.0-amazon-corretto.$(arch)/jre"
        JAVAC_PATH="/usr/lib/jvm/java-1.8.0-amazon-corretto.$(arch)/"
        ;;
    11)
        JDK_VERSION="corretto11"
        JAVA_PATH="/usr/lib/jvm/java-11-amazon-corretto.$(arch)"
        JAVAC_PATH="/usr/lib/jvm/java-11-amazon-corretto.$(arch)"
        ;;
    17)
        JDK_VERSION="corretto17"
        JAVA_PATH="/usr/lib/jvm/java-17-amazon-corretto.$(arch)"
        JAVAC_PATH="/usr/lib/jvm/java-11-amazon-corretto.$(arch)"
        ;;
    21)
        JDK_VERSION="corretto21"
        JAVA_PATH="/usr/lib/jvm/java-21-amazon-corretto.$(arch)"
        JAVAC_PATH="/usr/lib/jvm/java-11-amazon-corretto.$(arch)"
        ;;
esac

# 切换到新安装的版本
alternatives --set java  "${JAVA_PATH}/bin/java" && \
alternatives --set javac "${JAVAC_PATH}/bin/javac" && \
echo "✓ 已切换到 Corretto $version"  && \
java -version

#####################################################################################
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
#####################################################################################

yum  install -y htop dmidecode python3-pip
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
let THREADS_PROBE=64
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
aws s3 cp specjbb15-${JDK_VERSION}-${PN}-${DATATIME}.tar.gz ${aws_s3_bucket_name}/result_specjbb15/
aws s3 ls ${aws_s3_bucket_name}
echo "Upload specjbb15-${JDK_VERSION}-${PN}-${DATATIME}.tar.gz to ${aws_s3_bucket_name} ."

sleep 30

## Disable 服务，这样 reboot 后不会再次执行
systemctl disable userdata.service

# 停止实例
INSTANCE_ID=$(ec2-metadata --quiet --instance-id)
REGION_ID=$(ec2-metadata --quiet --region)
aws ec2 terminate-instances --instance-ids "${INSTANCE_ID}" --region "${REGION_ID}"