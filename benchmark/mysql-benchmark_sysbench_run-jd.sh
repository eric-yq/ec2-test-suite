#!/bin/bash

## 使用方法： bash mysql-benchmark_sysbench.sh <IP地址> <执行时间(分钟)> <表数量> <每个表记录条数> <线程数> <测试模式>

# set -e

SUT_IP_ADDR=${1}
OLTP_DURATION=${2}
TABLES=${3}
TABLE_SIZE=${4}
RUN_THREADS=${5}
PROFILE_MODE=${6}

cd ~/sysbench-1.0.20/

source /tmp/temp-setting
RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}.txt"

# 测试延迟
bash ~/ec2-test-suite/tools/mysql_latency_test.sh ${SUT_IP_ADDR} >> ${RESULT_FILE}

# 执行 Benchmark 测试
echo "====================================================================================" >> ${RESULT_FILE}
echo "$(date +%Y%m%d.%H%M%S) Start to run benchmark. " >> ${RESULT_FILE}
echo "Command Line Parameters: SUT_IP_ADDR=${1}, OLTP_DURATION=${2}, TABLES=${3}, TABLE_SIZE=${4}, RUN_THREADS=${5}, PROFILE_MODE=${6}" >> ${RESULT_FILE}

## 选择测试模式
if [ "$PROFILE_MODE" = "read_only" ]; then
  BENCHMARK_LUA="./src/lua/oltp_read_only.lua"

elif [ "$PROFILE_MODE" = "write_only" ]; then
  BENCHMARK_LUA="./src/lua/oltp_write_only.lua"

elif [ "$PROFILE_MODE" = "rw_default" ]; then
  BENCHMARK_LUA="./src/lua/oltp_read_write.lua"

elif [ "$PROFILE_MODE" = "rw_70_30" ]; then
  BENCHMARK_LUA="./src/lua/oltp_read_write.lua \
    --point-selects=14 --index-updates=3 --non-index-updates=3 \
    --simple-ranges=0 --sum-ranges=0 --order-ranges=0 --distinct-ranges=0 --delete-inserts=0"

elif [ "$PROFILE_MODE" = "rw_90_10" ]; then
  BENCHMARK_LUA="./src/lua/oltp_read_write.lua \
    --point-selects=18 --index-updates=1 --non-index-updates=1 \
    --simple-ranges=0 --sum-ranges=0 --order-ranges=0 --distinct-ranges=0 --delete-inserts=0"

elif [ "$PROFILE_MODE" = "point_select" ]; then
  BENCHMARK_LUA="./src/lua/oltp_point_select.lua"

elif [ "$PROFILE_MODE" = "update_index" ]; then
  BENCHMARK_LUA="./src/lua/oltp_update_index.lua"

elif [ "$PROFILE_MODE" = "update_non_index" ]; then
  BENCHMARK_LUA="./src/lua/oltp_update_non_index.lua"

else
  echo "Unsupported PROFILE_MODE: $PROFILE_MODE"
  exit 1
fi

## 执行 benchmark
RAMPUP_DURATION=0
let RUNTIMER_DURATION=$((${RAMPUP_DURATION}+${OLTP_DURATION}+1))*60
echo "[Run Benchmark]: " >> ${RESULT_FILE}
./src/sysbench $BENCHMARK_LUA \
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
  
echo "$(date +%Y%m%d.%H%M%S) Complete to run benchmark. " >> ${RESULT_FILE}
echo "====================================================================================" >> ${RESULT_FILE}

sleep 30