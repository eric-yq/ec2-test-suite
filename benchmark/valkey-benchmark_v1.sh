#!/bin/bash

## 使用方法： bash valkey-benchmark_v1.sh <IP地址> <执行时间(秒)>

## 场景 1
SUT_IP_ADDR=${1}
TEST_TIME=${2}

source /tmp/temp-setting
RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}

THREAD_LIST="2 4 6 8 10 12 16"
for i in ${THREAD_LIST}
do
# 	redis-cli -h ${SUT_IP_ADDR} flushall
	RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}-${i}.txt"
	
	if [[ ${SUT_NAME} == "valkey" ]]; then
	   OPTS="-t ${i} -c 4"
	elif [[ ${SUT_NAME} == "valkey-cluster" ]]; then
	   OPTS="-t ${i} -c 4 --cluster-mode "
	else 
	    echo "$0: Not suport $SUT_NAME in his script. "
	    exit 1
	fi
 
	memtier_benchmark ${OPTS} -s ${SUT_IP_ADDR} --test-time ${TEST_TIME} \
	  --distinct-client-seed \
	  --key-pattern=R:R --key-prefix=TEST \
	  --random-data --data-size-range=1-512 --data-size-pattern=S  \
	  −−randomize --hide-histogram --run-count=3 --ratio=1:5 \
	  --out-file=${RESULT_FILE}
done

# --pipeline 10 