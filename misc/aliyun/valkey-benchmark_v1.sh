#!/bin/bash

## 使用方法： bash redis-benchmark_v1.sh <IP地址> <端口号> <执行时间(秒)>

# 启用严格模式
set -e          # 命令失败时退出
set -o pipefail # 管道中的命令失败时也退出
set -u          # 使用未声明的变量时退出

## 场景 1
SUT_IP_ADDR=${1}
SUT_PORT=${2}
TEST_TIME=${3}

# 其他变量
SUT_NAME="valkey"
OS_TYPE="alinux3"
INSTANCE_TYPE=$(sshpass -p '3k3j9knjM' ssh root@$SUT_IP_ADDR "cloud-init query ds.meta-data.instance.instance-type")

# source /tmp/temp-setting
RESULT_PATH="/root/benchmark-result-files"
mkdir -p ${RESULT_PATH}

THREAD_LIST="1 2 4 6 8 12 16 32 48 64"

for i in ${THREAD_LIST}
do
        redis-cli -h ${SUT_IP_ADDR} -p ${SUT_PORT} flushall
        RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}_${SUT_PORT}_${i}.txt"

        OPTS="--threads ${i} --clients 4"

        memtier_benchmark ${OPTS} --server ${SUT_IP_ADDR} --port ${SUT_PORT} --test-time ${TEST_TIME} \
          --random-data --data-size-range=1-4096 --data-size-pattern=S \
          --hide-histogram --run-count=3 --ratio=1:4 --out-file=${RESULT_FILE}
done