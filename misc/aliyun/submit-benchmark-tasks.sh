#!/bin/bash

## 在 loadgen 上启动测试

screen -R ttt -L

cd /root/

########### ID 地址 ###########
IPADDR_R8Y="172.24.133.63"
IPADDR_R9I="172.24.133.60"
IPADDR_R9A="172.24.133.62"
IPADDR_R9AE="172.24.133.61"
##############################

##########################################################################################
## redis, valkey
IPADDR_R9A="172.24.133.62"
IPADDR=${IPADDR_R9A}
bash benchmark/redis-benchmark_v1.sh ${IPADDR} 6379 180
echo "[Info] Redis on $IPADDR complete."
echo "[Info] sleep 60 seconds for next benchmark..."
sleep 60
bash benchmark/valkey-benchmark_v1.sh ${IPADDR} 8007 180
echo "[Info] Valkey on $IPADDR complete."
echo "[Info] sleep 60 seconds for next benchmark..."


##########################################################################################
## mysql
IPADDR_R8Y="172.24.133.63"
IPADDR_R9I="172.24.133.XX"
IPADDR_R9A="172.24.133.xx"
IPADDR_R9AE="172.24.133.xx"
## 选择测试的 IP 地址
INSTANCE_IP_MASTER=$IPADDR_R8Y
## 准备数据
bash benchmark/mysql-benchmark_v2_prepare.sh ${INSTANCE_IP_MASTER} 64

## 使用不同的vuser执行benchmark
bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  1 64 
bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  2 64
bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  4 64 
bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  6 64  
bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  8 64 
bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 30 10 64 
bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 30 12 64
bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 30 16 64