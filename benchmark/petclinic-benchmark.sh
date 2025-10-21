#!/bin/bash

## 使用方法： bash petclinic-benchmark.sh <IP地址> <并发数>

SUT_IP_ADDR=${1}
SUT_PORT=8080
i=$2

source /tmp/temp-setting
RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}

## 启动一个后台进程，执行dool命令，获取系统性能信息
# DOOL_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}_dool.txt"
# ssh -o StrictHostKeyChecking=no -i ~/ericyq-global.pem ec2-user@${SUT_IP_ADDR} \
#   "sudo dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 5 100" \
#   1> ${DOOL_FILE} 2>&1 &

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}_${SUT_PORT}_${i}.jtl"
echo "[Info] Start jmeter test for PETCLINIC_HOST=${SUT_IP_ADDR}, USERS=$i ..."
jmeter -n -t $(dirname $0)/petclinic_test_plan.jmx \
  -JPETCLINIC_HOST=${SUT_IP_ADDR} \
  -JUSERS=$i \
  -JDURATION=90 \
  -f -l ${RESULT_FILE}

echo "[Info] Complete jmeter test for USERS=$i. "

#解析结果
REPORT_DIR="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}_${SUT_PORT}_${i}_report"
jmeter -g ${RESULT_FILE} -o ${REPORT_DIR}
# rm -rf ${RESULT_FILE}
