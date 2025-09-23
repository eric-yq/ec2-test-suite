#!/bin/bash

## 在 loadgen 上启动测试

screen -R ttt -L

########### ID 地址 ###########
IPADDR_R8Y="172.24.133.63"
IPADDR_R9I="172.24.133.60"
IPADDR_R9A="172.24.133.62"
IPADDR_R9AE="172.24.133.61"
##############################

##########################################################################################
## R8y: redis, valkey
IPADDR=$IPADDR_R8Y
bash benchmark/redis-benchmark_v1.sh ${INSTANCE_IP_MASTER} 6379 180
bash benchmark/valkey-benchmark_v1.sh ${INSTANCE_IP_MASTER} 8005 180


