#!/bin/bash

# al2023
yum groupinstall -y "Development Tools"
yum install -y cmake maven
yum install -y java-1.8.0-amazon-corretto java-1.8.0-amazon-corretto-devel
yum install -y zlib-devel zlib-static xz-devel snappy-devel jansson jansson-devel pkgconfig libatomic libatomic-static libstdc++-static

# 编译构建和安装
cd /root/
VER="ver-2.6.0.34"
git clone --branch release/$VER https://github.com/taosdata/TDengine.git TDengine-$VER 
cd TDengine-$VER
sed -i.bak "s/ make/ make -j $(expr $(nproc) - 2)/g" build.sh
./build.sh
cd debug/ && make install

# 启动
systemctl start  taosd
systemctl status taosd

sleep 10

# taosBenchmark
PN=$(dmidecode -s system-product-name | tr ' ' '_')
LOG_FILE="/root/result.log"
RESULT_SUMMARY="/root/taosbenchmark_summary_$PN.txt"
THREADS="4 8 12 16 24 32"

for i in $THREADS
do
    echo "[Info] Run taosBenchmark, --thread $i ......"
    taosBenchmark -y --thread $i >$LOG_FILE 2>&1
    wait $!
    echo "[Info] Result of Thread $i:" >> $RESULT_SUMMARY 
    grep "SUCC: Spent" $LOG_FILE >> $RESULT_SUMMARY 
    grep "SUCC: insert delay" $LOG_FILE >> $RESULT_SUMMARY 
done

echo "[Info] Complete all taosBenchmark."


