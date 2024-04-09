#!/bin/bash

## 使用方法： bash redis-benchmark.sh <IP地址> <执行时间(秒)>

OPTS="-t 8 -c 64"
if [[ ${SUT_NAME} == "redis-cluster" ]]; then
	OPTS="--cluster-mode -t 8 -c 256"
fi

## 场景 1
SUT_IP_ADDR=${1}
TEST_TIME=${2}

source /tmp/temp-setting
RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}.txt"

redis-cli -h ${SUT_IP_ADDR} flushall
memtier_benchmark ${OPTS} -s ${SUT_IP_ADDR} --test-time ${TEST_TIME} \
  --random-data --data-size-range=1024-4096 --data-size-pattern=S \
  --hide-histogram --run-count=3 --ratio=1:4 \
  --out-file=${RESULT_FILE}



# al2 
# SUT_IP_ADDR="172.31.22.93"
# al2023
# SUT_IP_ADDR="172.31.31.108"
# ubuntu2204
# SUT_IP_ADDR="172.31.30.65"

# cache.r6g.2xlarge 6.2.6
# SUT_IP_ADDR="redis62-master-slave.fmisxs.ng.0001.use2.cache.amazonaws.com"

# al2 , dedicated host.
# SUT_IP_ADDR="172.31.26.169"
# 
# redis-cli -h ${SUT_IP_ADDR} flushall
# memtier_benchmark t 8 -c 64 -s ${SUT_IP_ADDR} --test-time 180 \
#   --random-data --data-size-range=1024-4096 --data-size-pattern=S \
#   --hide-histogram --run-count=3 --ratio=1:4