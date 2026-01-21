#!/bin/bash

## 使用方法： bash mysql-benchmark_sysbench_prepare.sh <IP地址> <执行时间(分钟)> <表数量> <每个表记录条数>

# set -e

SUT_IP_ADDR=${1}
OLTP_DURATION=${2}
TABLES=${3}
TABLE_SIZE=${4}
RUN_THREADS=8

cd ~/sysbench-1.0.20/

source /tmp/temp-setting
RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}.txt"

## 启动一个后台进程，执行dool命令，获取系统性能信息
## Note: prepare: 按 38 分钟计算;  run: 按 64*8=512 分钟计算 ，总计打印 550 分钟的监控信息。
DOOL_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}_dool.txt"
ssh -o StrictHostKeyChecking=no -i ~/ericyq-global.pem ec2-user@${SUT_IP_ADDR} \
  "dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60 550" \
  1> ${DOOL_FILE} 2>&1 &

echo "Test Detail on $(date)====================================================================================" >> ${RESULT_FILE}
echo "Command Line Parameters: SUT_IP_ADDR=${1}, OLTP_DURATION=${2}, TABLES=${3}, TABLE_SIZE=${4}" >> ${RESULT_FILE}

## 准备数据
mysql -h ${SUT_IP_ADDR} -p'gv2mysql' << EOF
drop database if exists oltp;
create database oltp;
EOF

echo "[Prepare Tables]: " >> ${RESULT_FILE}
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
  prepare >> ${RESULT_FILE}
  
## 更新 schema_information
echo "[Analyze Tables]: " >> ${RESULT_FILE}
for i in $(seq 1 $TABLES)
do
    mysql -h $SUT_IP_ADDR -p'gv2mysql' -e "analyze table oltp.sbtest$i;"  >> ${RESULT_FILE}
done

database_statics=$(mysql -h $SUT_IP_ADDR -p'gv2mysql' -e "select table_schema as '数据库', sum(table_rows) as '记录数', sum(truncate(data_length/1024/1024, 2)) as '数据容量(MB)', sum(truncate(index_length/1024/1024, 2)) as '索引容量(MB)' from information_schema.tables where table_schema='oltp';")
table_statics=$(mysql -h $SUT_IP_ADDR -p'gv2mysql' -e "select table_schema as '数据库', table_name as '表名', table_rows as '记录数', truncate(data_length/1024/1024, 2) as '数据容量(MB)', truncate(index_length/1024/1024, 2) as '索引容量(MB)' from information_schema.tables where table_schema='oltp' order by data_length desc, index_length desc;")

echo "[Build Schema Summary]: " >> ${RESULT_FILE}
echo "$database_statics" >> ${RESULT_FILE}
echo "$table_statics" >> ${RESULT_FILE}

echo "Prepare Completed on $(date)==================================================================================" >> ${RESULT_FILE}

# 测试延迟
sleep 30
bash ~/ec2-test-suite/tools/mysql_latency_test.sh ${SUT_IP_ADDR} >> ${RESULT_FILE}