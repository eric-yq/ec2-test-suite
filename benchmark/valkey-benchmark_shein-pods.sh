#!/bin/bash

#####################################################################
## 这个脚本是shein提供的测试命令，在一个EC2实例上启动多个pods时的测试。
## 使用方法： bash valkey-benchmark_shein-pods.sh <IP地址> <端口号>
#####################################################################

## 场景 1
SUT_IP_ADDR=${1}
PORT=${2}
DATASIZE=32

source /tmp/temp-setting
RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}-shein-set.txt"
memtier_benchmark -t 2 -c 5 --pipeline=10 -s ${SUT_IP_ADDR} -p $PORT --distinct-client-seed --command="set __key__ __data__" --key-prefix="kv_" --key-minimum=1 --key-maximum=500 --random-data --data-size=$DATASIZE --test-time=180 --out-file=${RESULT_FILE} --hide-histogram 

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}-shein-get.txt"
memtier_benchmark -t 2 -c 5 --pipeline=10 -s ${SUT_IP_ADDR} -p $PORT --distinct-client-seed --command="get __key__" --key-prefix="kv_" --key-minimum=1 --key-maximum=500 --test-time=180 --out-file=${RESULT_FILE} --hide-histogram 

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}-shein-incr.txt"
memtier_benchmark -t 2 -c 5 --pipeline=10 -s ${SUT_IP_ADDR} -p $PORT --distinct-client-seed --command="incr __key__" --key-prefix="int_" --key-minimum=1 --key-maximum=500 --test-time=180 --out-file=${RESULT_FILE} --hide-histogram 

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}-shein-lpush.txt"
memtier_benchmark -t 2 -c 5 --pipeline=10 -s ${SUT_IP_ADDR} -p $PORT --distinct-client-seed --command="lpush __key__ __data__" --key-prefix="list_" --key-minimum=1 --key-maximum=500 --random-data --data-size=$DATASIZE --test-time=180 --out-file=${RESULT_FILE} --hide-histogram 

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}-shein-sadd.txt"
memtier_benchmark -t 2 -c 5 --pipeline=10 -s ${SUT_IP_ADDR} -p $PORT --distinct-client-seed --command="sadd __key__ __data__" --key-prefix="set_" --key-minimum=1 --key-maximum=500 --random-data --data-size=$DATASIZE --test-time=180 --out-file=${RESULT_FILE} --hide-histogram 

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}-shein-zadd.txt"
memtier_benchmark -t 2 -c 5 --pipeline=10 -s ${SUT_IP_ADDR} -p $PORT --distinct-client-seed --command="zadd __key__ __key__ __data__" --key-prefix="" --key-minimum=1 --key-maximum=500 --random-data --data-size=$DATASIZE --test-time=180 --out-file=${RESULT_FILE} --hide-histogram 

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}-shein-hset.txt"
memtier_benchmark -t 2 -c 5 --pipeline=10 -s ${SUT_IP_ADDR} -p $PORT --distinct-client-seed --command="hset __key__ __data__ __data__" --key-prefix="hash_" --key-minimum=1 --key-maximum=500 --random-data --data-size=$DATASIZE --test-time=180 --out-file=${RESULT_FILE} --hide-histogram 
