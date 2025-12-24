#!/bin/bash

## 使用方法： bash redis-benchmark_v1.sh <IP地址> <端口号> <执行时间(秒)>

# OPTS="-t 8 -c 64"
# if [[ ${SUT_NAME} == "redis-cluster" ]]; then
# 	OPTS="--cluster-mode -t 8 -c 256"
# fi

## 场景 1
SUT_IP_ADDR=${1}
SUT_PORT=${2}
TEST_TIME=${3}

source /tmp/temp-setting
RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}

## 启动一个后台进程，执行dool命令，获取系统性能信息
DOOL_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}_dool.txt"
ssh -o StrictHostKeyChecking=no -i ~/ericyq-global.pem ec2-user@${SUT_IP_ADDR} \
  "sudo dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60 200" \
  1> ${DOOL_FILE} 2>&1 &

# 预热数据 - 只执行一次
echo "预热Redis数据..."
redis-cli -h ${SUT_IP_ADDR} flushall
memtier_benchmark --threads 4 --clients 4 --server ${SUT_IP_ADDR} --port ${SUT_PORT} \
    --ratio 1:0 --requests 100000 --key-maximum 100000 --data-size 512 > /dev/null 2>&1

THREAD_LIST="1 2 4 6 8 12 16 32"

for i in ${THREAD_LIST}
do
	RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}_${SUT_PORT}_${i}.txt"
	
	OPTS="--threads ${i} --clients 4"

    memtier_benchmark ${OPTS} --server ${SUT_IP_ADDR} --port ${SUT_PORT} --test-time ${TEST_TIME} \
        --ratio 1:4 --key-maximum 100000 --data-size 512 \
        --run-count 3  --hide-histogram --out-file ${RESULT_FILE}

    sleep 10
done
