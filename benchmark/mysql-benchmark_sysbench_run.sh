#!/bin/bash

## 使用方法： bash mysql-benchmark_sysbench.sh <IP地址> <执行时间(分钟)> <表数量> <每个表记录条数> <线程数>

# set -e

SUT_IP_ADDR=${1}
OLTP_DURATION=${2}
TABLES=${3}
TABLE_SIZE=${4}
RUN_THREADS=${5}

cd ~/sysbench-1.0.20/

source /tmp/temp-setting
RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}.txt"

echo "Test Detail on $(date)====================================================================================" >> ${RESULT_FILE}
echo "Command Line Parameters: SUT_IP_ADDR=${1}, OLTP_DURATION=${2}, TABLES=${3}, TABLE_SIZE=${4}, RUN_THREADS=${5}" >> ${RESULT_FILE}

## 执行 benchmark
RAMPUP_DURATION=0
let RUNTIMER_DURATION=$((${RAMPUP_DURATION}+${OLTP_DURATION}+1))*60
echo "[Run Benchmark]: " >> ${RESULT_FILE}
./src/sysbench ./src/lua/oltp_read_write.lua \
  --mysql-host=$SUT_IP_ADDR \
  --mysql-port=3306 \
  --mysql-user=root \
  --mysql-password='gv2mysql' \
  --mysql-db=oltp \
  --db-driver=mysql \
  --tables=$TABLES \
  --table-size=$TABLE_SIZE \
  --report-interval=300 \
  --threads=$RUN_THREADS \
  --time=$RUNTIMER_DURATION \
  run  >> ${RESULT_FILE}
  