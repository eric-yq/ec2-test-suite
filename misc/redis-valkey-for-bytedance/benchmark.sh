#!/bin/bash

##########################################################################################################
## 这个脚本使用 shein 提供的测试命令进行 benchmark 测试，适用于Valkey 和 Redis
## 使用方法： bash benchmark.sh <服务器类型> <IP地址> <端口号> <memtier线程数> <memtier线程数>
##########################################################################################################

## 获取测试参数
SUT_NAME=${1}
SUT_IP_ADDR=${2}
PORT=${3}
THREADS=${4}
CONNECTIONS=${5}

RESULT_PATH="/root/yuanquan/redis-valkey-benchmark-for-bytedance"
mkdir -p ${RESULT_PATH}

# 获取valkey 所在服务器的信息
INSTANCE_TYPE=$(ssh -o StrictHostKeyChecking=no -i ~/ericyq-global.pem ec2-user@${SUT_IP_ADDR} "sudo ec2-metadata --quiet --instance-type")

# 设置 memtier 选项
OPTS="-s ${SUT_IP_ADDR} -p $PORT -t $THREADS -c $CONNECTIONS --test-time=180 --distinct-client-seed --key-minimum=1 --key-maximum=1 --print-percentiles 50,99,100 "

## 启动一个后台进程，执行dool命令，获取系统性能信息
DOOL_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}_t${THREADS}_c${CONNECTIONS}_dool.txt"
ssh -o StrictHostKeyChecking=no -i ~/ericyq-global.pem ec2-user@${SUT_IP_ADDR} \
  "dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60 16" \
  1> ${DOOL_FILE} 2>&1 &

# 执行benchmark
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}_t${THREADS}_c${CONNECTIONS}_set64_bytedance.txt"
memtier_benchmark $OPTS --command="set __key__ __data__" --key-prefix="kv_" --random-data --data-size=64 --out-file=${RESULT_FILE}  

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}_t${THREADS}_c${CONNECTIONS}_set512_bytedance.txt"
memtier_benchmark $OPTS --command="set __key__ __data__" --key-prefix="kv_" --random-data --data-size=512 --out-file=${RESULT_FILE}  

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}_t${THREADS}_c${CONNECTIONS}_get_bytedance.txt"
memtier_benchmark $OPTS --command="get __key__" --key-prefix="kv_" --out-file=${RESULT_FILE} 

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}_t${THREADS}_c${CONNECTIONS}_incr_bytedance.txt"
memtier_benchmark $OPTS --command="incr __key__" --key-prefix="int_" --out-file=${RESULT_FILE} 

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}_t${THREADS}_c${CONNECTIONS}_decr_bytedance.txt"
memtier_benchmark $OPTS --command="decr __key__" --key-prefix="int_" --out-file=${RESULT_FILE} 
