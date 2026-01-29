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
DOOL_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}_dool-sut.txt"
# 先测试一下 ping 延迟
echo "测试 Redis Client-Server 延迟 (ping 60 次)" >> ${DOOL_FILE}
echo "==========================================" >> ${DOOL_FILE}
ping -q -c 60 ${INSTANCE_IP_MASTER} >> ${DOOL_FILE}
echo "==========================================" >> ${DOOL_FILE}
# 启动监控: sut
ssh -o StrictHostKeyChecking=no -i ~/ericyq-global.pem ec2-user@${SUT_IP_ADDR} \
  "dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 10" \
  1>> ${DOOL_FILE} 2>&1 &
# 启动监控:loadgen
DOOL_FILE_LOADGEN="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}_dool-loadgen.txt"
nohup dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 10 \
  1>> ${DOOL_FILE_LOADGEN} 2>&1 &

# 定义测试命令
declare -A COMMANDS=(
    ["SET"]="SET {key uniform 10000000} {value 64}"
    ["GET"]="GET {key uniform 10000000}"
)

THREAD_LIST="10 50 200 500 1000 2000 3000 5000 7000 9000"

# 执行测试
for COMMAND in "${!COMMANDS[@]}"; do
    OPT="${COMMANDS[$COMMAND]}"
    echo "Testing ${COMMAND}..."
    
    for THREADS in ${THREAD_LIST}; do
        RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}_${SUT_PORT}_${COMMAND}_${THREADS}.txt"
        
        echo "  Threads: ${THREADS}"
        resp-benchmark -h ${SUT_IP_ADDR} -p ${SUT_PORT} -s ${TEST_TIME} \
          -P 5 "${OPT}" -c ${THREADS} > ${RESULT_FILE} 2>&1
        sleep 30
    done
done

# 停止 dool 监控
killall ssh dool