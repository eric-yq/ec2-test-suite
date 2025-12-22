#!/bin/bash

## 使用方法： bash redis-benchmark.sh <IP地址> <执行时间(秒)>


# 执行OS优化
bash $(dirname $0)/os-optimization.sh


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
