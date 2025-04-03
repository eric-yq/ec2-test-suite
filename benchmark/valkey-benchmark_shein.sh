#!/bin/bash

#####################################################################
## 这个脚本是shein提供的测试命令
## 使用方法： bash valkey-benchmark_shein.sh <IP地址> <端口号> <pipeline数>
#####################################################################

# # 执行OS优化
# bash /root/ec2-test-suite/benchmark/os-optimization.sh

## 场景 1
SUT_IP_ADDR=${1}
PORT=${2}
PPL=${3}

source /tmp/temp-setting
RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}

# 获取valkey服务器配置
VALKEY_CFG="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}.conf"
valkey-cli -h ${SUT_IP_ADDR} -p ${PORT} config get \* > ${VALKEY_CFG}

# 获取valkey 所在服务器的 cpu 信息
VCPU=$(ssh -o StrictHostKeyChecking=no -i ~/ericyq-global.pem ec2-user@${SUT_IP_ADDR} "nproc")
if [[ "$PPL" == "0" ]]; then
    OPTS="-t $VCPU -c 50"
else
    OPTS="-t $VCPU -c 50 --pipeline=$PPL"
fi
echo "OPTS: $OPTS"

## 启动一个后台进程，执行dool命令，获取系统性能信息
DOOL_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}_dool.txt"
ssh -o StrictHostKeyChecking=no -i ~/ericyq-global.pem ec2-user@${SUT_IP_ADDR} \
  "dool --cpu --sys --net --net-packets --disk --io --proc-count --time --bits 60 23" \
  1> ${DOOL_FILE} 2>&1 &

# 执行benchmark
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}_set_shein.txt"
memtier_benchmark $OPTS -s ${SUT_IP_ADDR} -p $PORT --distinct-client-seed --command="set __key__ __data__" --key-prefix="kv_" --key-minimum=1 --key-maximum=500 --random-data --data-size=128 --test-time=180 --out-file=${RESULT_FILE}  --hide-histogram 

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}_get_shein.txt"
memtier_benchmark $OPTS -s ${SUT_IP_ADDR} -p $PORT --distinct-client-seed --command="get __key__" --key-prefix="kv_" --key-minimum=1 --key-maximum=500 --test-time=180 --out-file=${RESULT_FILE} --hide-histogram 

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}_incr_shein.txt"
memtier_benchmark $OPTS -s ${SUT_IP_ADDR} -p $PORT --distinct-client-seed --command="incr __key__" --key-prefix="int_" --key-minimum=1 --key-maximum=500 --test-time=180 --out-file=${RESULT_FILE} --hide-histogram 

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}_lpush_shein.txt"
memtier_benchmark $OPTS -s ${SUT_IP_ADDR} -p $PORT --distinct-client-seed --command="lpush __key__ __data__" --key-prefix="list_" --key-minimum=1 --key-maximum=500 --random-data --data-size=128 --test-time=180 --out-file=${RESULT_FILE} --hide-histogram 

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}_sadd_shein.txt"
memtier_benchmark $OPTS -s ${SUT_IP_ADDR} -p $PORT --distinct-client-seed --command="sadd __key__ __data__" --key-prefix="set_" --key-minimum=1 --key-maximum=500 --random-data --data-size=128 --test-time=180 --out-file=${RESULT_FILE} --hide-histogram 

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}_zadd_shein.txt"
memtier_benchmark $OPTS -s ${SUT_IP_ADDR} -p $PORT --distinct-client-seed --command="zadd __key__ __key__ __data__" --key-prefix="" --key-minimum=1 --key-maximum=500 --random-data --data-size=128 --test-time=180 --out-file=${RESULT_FILE} --hide-histogram 

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}_hset_shein.txt"
memtier_benchmark $OPTS -s ${SUT_IP_ADDR} -p $PORT --distinct-client-seed --command="hset __key__ __data__ __data__" --key-prefix="hash_" --key-minimum=1 --key-maximum=500 --random-data --data-size=128 --test-time=180 --out-file=${RESULT_FILE} --hide-histogram 
