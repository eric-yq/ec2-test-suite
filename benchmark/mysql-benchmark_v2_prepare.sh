#!/bin/bash

## 使用方法： bash mysql-benchmark_v2_prepare.sh <IP地址> <数据量(G)> <FLAG1(optional)>

# set -e

SUT_IP_ADDR=${1}
DATA_SIZE=${2}
FLAG1=${3}

let WARES=${DATA_SIZE}*1024/90
echo "Warehouse: ${WARES}, Data size: ${DATA_SIZE}"

cd ~/HammerDB-4.4/

## 创建 buildschema 脚本VUSER_NUM
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

## 执行 benchmark 测试，准备数据
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

## 启动一个后台进程，执行dool命令，获取系统性能信息
DOOL_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}_dool-sut.txt"
ssh -o StrictHostKeyChecking=no -i ~/ericyq-global.pem ec2-user@${SUT_IP_ADDR} \
  "dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60" \
  1> ${DOOL_FILE} 2>&1 &
DOOL_FILE_LOADGEN="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}_dool-loadgen.txt"
nohup dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60 \
  1> ${DOOL_FILE_LOADGEN} 2>&1 &

echo "Test Detail on $(date)====================================================================================" >> ${RESULT_FILE}
## 远程输出 /etc/my.cnf 内容
echo "Export MySQL configuration /etc/my.cnf first... " >> ${RESULT_FILE}
ssh -o StrictHostKeyChecking=no -i ~/ericyq-global.pem ec2-user@${SUT_IP_ADDR} "sudo cat /etc/my.cnf" >> ${RESULT_FILE}

## 准备数据
echo "Start to prepare data. SUT_IP_ADDR=${SUT_IP_ADDR}, Data size: ${DATA_SIZE}, Warehouse: ${WARES},, FLAG1=${5}" >> ${RESULT_FILE}
mysql -h ${SUT_IP_ADDR} -p'gv2mysql' -e "drop database tpcc;"
./hammerdbcli auto tpcc_buildschema.tcl

sleep 10

## 更新 schema_information
mysql -h ${SUT_IP_ADDR} -p'gv2mysql' << EOF
analyze table tpcc.stock;
analyze table tpcc.order_line;
analyze table tpcc.customer;
analyze table tpcc.history;
analyze table tpcc.orders;
analyze table tpcc.new_order;
analyze table tpcc.item;
analyze table tpcc.district;
analyze table tpcc.warehouse;
EOF

database_statics=$(mysql -h $SUT_IP_ADDR -p'gv2mysql' -e "select table_schema as '数据库', sum(table_rows) as '记录数', sum(truncate(data_length/1024/1024, 2)) as '数据容量(MB)', sum(truncate(index_length/1024/1024, 2)) as '索引容量(MB)' from information_schema.tables where table_schema='tpcc';")
table_statics=$(mysql -h $SUT_IP_ADDR -p'gv2mysql' -e "select table_schema as '数据库', table_name as '表名', table_rows as '记录数', truncate(data_length/1024/1024, 2) as '数据容量(MB)', truncate(index_length/1024/1024, 2) as '索引容量(MB)' from information_schema.tables where table_schema='tpcc' order by data_length desc, index_length desc;")

echo "[Build Schema Summary]: " >> ${RESULT_FILE}
echo "$database_statics" >> ${RESULT_FILE}
echo "$table_statics" >> ${RESULT_FILE}

echo "Complete to prepare data. " >> ${RESULT_FILE}

# 测试延迟
sleep 30
bash ~/ec2-test-suite/tools/mysql_latency_test.sh ${SUT_IP_ADDR} >> ${RESULT_FILE}