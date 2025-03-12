#!/bin/bash

#####################################################################
## 这个脚本是shein提供的测试命令
## 使用方法： bash valkey-benchmark_shein.sh <IP地址>
#####################################################################

## 场景 1
SUT_IP_ADDR=${1}

source /tmp/temp-setting
RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}

# RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}-shein-set.txt"
# memtier_benchmark -t 20 -c 50 --pipeline=50 -s ${SUT_IP_ADDR} -p 6379 --distinct-client-seed --command="set __key__ __data__" --key-prefix="kv_" --key-minimum=1 --key-maximum=500 --random-data --data-size=128 --test-time=180 --out-file=${RESULT_FILE} 
# 
# RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}-shein-get.txt"
# memtier_benchmark -t 20 -c 50 --pipeline=50 -s ${SUT_IP_ADDR} -p 6379 --distinct-client-seed --command="get __key__" --key-prefix="kv_" --key-minimum=1 --key-maximum=500 --test-time=180 --out-file=${RESULT_FILE}
# 
# RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}-shein-incr.txt"
# memtier_benchmark -t 20 -c 50 --pipeline=50 -s ${SUT_IP_ADDR} -p 6379 --distinct-client-seed --command="incr __key__" --key-prefix="int_" --key-minimum=1 --key-maximum=500 --test-time=180 --out-file=${RESULT_FILE}
# 
# RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}-shein-lpush.txt"
# memtier_benchmark -t 20 -c 50 --pipeline=50 -s ${SUT_IP_ADDR} -p 6379 --distinct-client-seed --command="lpush __key__ __data__" --key-prefix="list_" --key-minimum=1 --key-maximum=500 --random-data --data-size=128 --test-time=180 --out-file=${RESULT_FILE}
# 
# RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}-shein-sadd.txt"
# memtier_benchmark -t 20 -c 50 --pipeline=50 -s ${SUT_IP_ADDR} -p 6379 --distinct-client-seed --command="sadd __key__ __data__" --key-prefix="set_" --key-minimum=1 --key-maximum=500 --random-data --data-size=128 --test-time=180 --out-file=${RESULT_FILE}
# 
# RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}-shein-zadd.txt"
# memtier_benchmark -t 20 -c 50 --pipeline=50 -s ${SUT_IP_ADDR} -p 6379 --distinct-client-seed --command="zadd __key__ __key__ __data__" --key-prefix="" --key-minimum=1 --key-maximum=500 --random-data --data-size=128 --test-time=180 --out-file=${RESULT_FILE}
# 
# RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}-shein-hset.txt"
# memtier_benchmark -t 20 -c 50 --pipeline=50 -s ${SUT_IP_ADDR} -p 6379 --distinct-client-seed --command="hset __key__ __data__ __data__" --key-prefix="hash_" --key-minimum=1 --key-maximum=500 --random-data --data-size=128 --test-time=180 --out-file=${RESULT_FILE}


#### 非pipelne模式
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}-shein-set.txt"
memtier_benchmark -t 20 -c 50  -s ${SUT_IP_ADDR} -p 6379 --distinct-client-seed --command="set __key__ __data__" --key-prefix="kv_" --key-minimum=1 --key-maximum=500 --random-data --data-size=128 --test-time=180 --out-file=${RESULT_FILE} 

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}-shein-get.txt"
memtier_benchmark -t 20 -c 50  -s ${SUT_IP_ADDR} -p 6379 --distinct-client-seed --command="get __key__" --key-prefix="kv_" --key-minimum=1 --key-maximum=500 --test-time=180 --out-file=${RESULT_FILE}

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}-shein-incr.txt"
memtier_benchmark -t 20 -c 50  -s ${SUT_IP_ADDR} -p 6379 --distinct-client-seed --command="incr __key__" --key-prefix="int_" --key-minimum=1 --key-maximum=500 --test-time=180 --out-file=${RESULT_FILE}

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}-shein-lpush.txt"
memtier_benchmark -t 20 -c 50   -s ${SUT_IP_ADDR} -p 6379 --distinct-client-seed --command="lpush __key__ __data__" --key-prefix="list_" --key-minimum=1 --key-maximum=500 --random-data --data-size=128 --test-time=180 --out-file=${RESULT_FILE}

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}-shein-sadd.txt"
memtier_benchmark -t 20 -c 50   -s ${SUT_IP_ADDR} -p 6379 --distinct-client-seed --command="sadd __key__ __data__" --key-prefix="set_" --key-minimum=1 --key-maximum=500 --random-data --data-size=128 --test-time=180 --out-file=${RESULT_FILE}

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}-shein-zadd.txt"
memtier_benchmark -t 20 -c 50   -s ${SUT_IP_ADDR} -p 6379 --distinct-client-seed --command="zadd __key__ __key__ __data__" --key-prefix="" --key-minimum=1 --key-maximum=500 --random-data --data-size=128 --test-time=180 --out-file=${RESULT_FILE}

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}-shein-hset.txt"
memtier_benchmark -t 20 -c 50   -s ${SUT_IP_ADDR} -p 6379 --distinct-client-seed --command="hset __key__ __data__ __data__" --key-prefix="hash_" --key-minimum=1 --key-maximum=500 --random-data --data-size=128 --test-time=180 --out-file=${RESULT_FILE}
