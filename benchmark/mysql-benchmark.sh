#!/bin/bash

## 使用方法： bash mysql-benchmark.sh <IP地址> <执行时间(分钟)>

# set -e

### 可以按照 vCPU 数量设置 warehouse 和 vus
### 例如: 8xlarge, 32 vCPU, 设置 1024 warehouse, 256 vus.
### 因此：warehouse = 32* vCPU, vus = 8* vCPU
### 8xlarge: 32 vCPU, 1024 warehouse, 256 vus
### 4xlarge: 16 vCPU, 512 warehouse, 128 vus.
### 2xlarge:  8 vCPU, 256 warehouse, 64 vus.

SUT_IP_ADDR=${1}
TPCC_DURATION=${2}

source /tmp/temp-setting
VCPU_NUM=${INSTANCE_VCPU_NUM}

## 临时
# WARES=128
# VUS=32

if   [[ X"${VCPU_NUM}" == "X" ]]; then

    echo "Not set vCPU number. Set to default 256 warehouse and 64 vus."
    let WARES=256
	let VUS=${WARES}/4

else

    let WARES=${VCPU_NUM}*32
	let VUS=${VCPU_NUM}*8
    echo "Warehouse: ${WARES}, Vusers: ${VUS}"

fi

## 安装hammerdb
# cd ~
#wget https://github.com/TPC-Council/HammerDB/releases/download/v4.4/HammerDB-4.4-Linux.tar.gz
#tar zxf HammerDB-4.4-Linux.tar.gz
cd ~/HammerDB-4.4/

## 创建 buildschema 脚本
cat << EOF > tpcc_buildschema.tcl
dbset db mysql
dbset bm TPC-C
diset connection mysql_host ${SUT_IP_ADDR}
diset tpcc mysql_pass gv2mysql
diset tpcc mysql_count_ware ${WARES}
diset tpcc mysql_num_vu 16
buildschema
waittocomplete
vudestroy
EOF

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
RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}-hammerdb.txt"
RESULT_FILE1="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}-hdbxtprofile.txt"

mysql -h ${SUT_IP_ADDR} -p'gv2mysql' -e "drop database tpcc;"
./hammerdbcli auto tpcc_buildschema.tcl
./hammerdbcli auto tpcc_vurun.tcl > ${RESULT_FILE}
sed -i "s/\x0D//g" ${RESULT_FILE}
mv /tmp/hdbxtprofile.log ${RESULT_FILE1}