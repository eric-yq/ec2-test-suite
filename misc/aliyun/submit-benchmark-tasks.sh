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
## R8y: redis, valkey
IPADDR=${IPADDR_R9I}
bash benchmark/redis-benchmark_v1.sh ${IPADDR} 6379 180
echo "[Info] Redis on $IPADDR complete."
echo "[Info] sleep 60 seconds for next benchmark..."
sleep 60
bash benchmark/valkey-benchmark_v1.sh ${IPADDR} 8005 180
echo "[Info] Valkey on $IPADDR complete."
echo "[Info] sleep 60 seconds for next benchmark..."
