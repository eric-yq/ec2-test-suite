#!/bin/bash

## 使用方法： bash mysql-benchmark_sysbench.sh <IP地址> <执行时间(分钟)> <表数量> <每个表记录条数> <线程数>

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

echo "Test Detail on $(date)====================================================================================" >> ${RESULT_FILE}
echo "Command Line Parameters: SUT_IP_ADDR=${1}, OLTP_DURATION=${2}, TABLES=${3}, TABLE_SIZE=${4}, RUN_THREADS=${5}, PROFILE_MODE=${6}" >> ${RESULT_FILE}

read_only, oltp_read_only,
write_only, oltp_write_only, 
rw_default, oltp_read_write,
rw_70_30, oltp_read_only, "--point-selects=10 --range-selects=off"
rw_90_10,
point_select, oltp_point_select,
update_index, oltp_update_index,
update_non_index, oltp_update_non_index,


if [ "$PROFILE_MODE" = "read_only" ]; then
  BENCHMARK_LUA="./src/lua/oltp_read_only.lua"

elif [ "$PROFILE_MODE" = "write_only" ]; then
  BENCHMARK_LUA="./src/lua/oltp_write_only.lua"

elif [ "$PROFILE_MODE" = "rw_default" ]; then
  BENCHMARK_LUA="./src/lua/oltp_read_write.lua"

elif [ "$PROFILE_MODE" = "rw_70_30" ]; then
  BENCHMARK_LUA="./src/lua/oltp_read_write.lua --point-selects=10 --range-selects=off"

elif [ "$PROFILE_MODE" = "rw_90_10" ]; then
  BENCHMARK_LUA="./src/lua/oltp_read_write.lua --point-selects=9 --range-selects=1"

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
  