#!/bin/bash

## 使用方法： bash mysql-benchmark_v2_run.sh <IP地址> <执行时间(分钟)> <VU_Number> <数据量(G)> <FLAG1(optional)>

# set -e

SUT_IP_ADDR=${1}
TPCC_DURATION=${2}
VUSER_NUM=${3}
DATA_SIZE=${4}
FLAG1=${5}

let WARES=${DATA_SIZE}*1024/90
let VUS=${VUSER_NUM}
echo "Warehouse: ${WARES}, Vusers: ${VUS}"

cd ~/HammerDB-4.4/

## 创建 运行 benchmark 脚本
RAMPUP_DURATION=3
let RUNTIMER_DURATION=$((${RAMPUP_DURATION}+${TPCC_DURATION}+1))*60

cat << EOF > tpcc_vurun.tcl
dbset db mysql
dbset bm TPC-C
diset connection mysql_host ${SUT_IP_ADDR}
diset tpcc mysql_pass gv2mysql
diset tpcc mysql_count_ware ${WARES}
diset tpcc mysql_num_vu 16
diset tpcc mysql_driver timed
diset tpcc mysql_rampup ${RAMPUP_DURATION}
diset tpcc mysql_duration ${TPCC_DURATION}
diset tpcc mysql_allwarehouse true
diset tpcc mysql_timeprofile true
vuset vu ${VUS}
vuset logtotemp 1
vuset showoutput 0
vuset unique 1
loadscript
vucreate
vurun
runtimer ${RUNTIMER_DURATION}
vudestroy
clearscript
EOF

## 执行 benchmark 测试
source /tmp/temp-setting

if [[ x"$SUT_NAME" == x ]]; then
    SUT_NAME="mysql_hammerdb"
fi

if [[ x"$INSTANCE_TYPE" == x ]]; then
    INSTANCE_TYPE=$FLAG1
fi

if [[ x"$INSTANCE_IP_MASTER" == x ]]; then
    INSTANCE_IP_MASTER=$SUT_IP_ADDR
fi

RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}.txt"

echo "Test Detail on $(date)====================================================================================" >> ${RESULT_FILE}
echo "Start to perform test: SUT_IP_ADDR=${1}, TPCC_DURATION=${2}, VUSER_NUM=${3}, Warehouse=${WARES}, FLAG1=${5}" >> ${RESULT_FILE}

## 执行 benchmark
./hammerdbcli auto tpcc_vurun.tcl > ./temp-output.log

## 获取 metric
grep "TEST RESULT" ./temp-output.log >> ${RESULT_FILE}
tail -n 17 /tmp/hdbxtprofile.log     >> ${RESULT_FILE}
