#!/bin/bash

## 使用方法： sh 01-mongodb-4.0.12.sh <IP地址>

submit_task(){
    SUT_IP_ADDR=${1}
    
    ## Profile: workload
    for i in {1..1}
    do
        ### 加载数据
        remove_keyspace
        create_keyspace
        /root/ycsb-0.17.0/bin/ycsb load cassandra-cql -P $(dirname $0)/workload_cassandra -p hosts=${SUT_IP_ADDR} \
          >> ${RESULT_FILE}

        ### 执行 Benchmark
        /root/ycsb-0.17.0/bin/ycsb  run cassandra-cql -P $(dirname $0)/workload_cassandra -p hosts=${SUT_IP_ADDR} \
          >> ${RESULT_FILE1}

        echo "Test ${i} finished."
        sleep 10
    done
    echo "All test completed."
}

create_keyspace(){
    cqlsh ${SUT_IP_ADDR} -e "\
        create keyspace ycsb WITH REPLICATION = {'class' : 'SimpleStrategy', 'replication_factor': 1 };\
        USE ycsb;\
		create table usertable ( \
			y_id varchar primary key, \
			field0	varchar,	\
			field1	varchar,	\
			field2	varchar,	\
			field3	varchar,	\
			field4	varchar,	\
			field5	varchar,	\
			field6	varchar,	\
			field7	varchar,	\
			field8	varchar,	\
			field9	varchar);	\
		DESCRIBE KEYSPACE ycsb;"
}

remove_keyspace(){
    cqlsh ${SUT_IP_ADDR} -e "\
        describe keyspaces;\
        drop keyspace ycsb;\
        describe keyspaces;"
}


## 执行 benchmark 测试
source /tmp/temp-setting
RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}-ycsb-load.txt"
RESULT_FILE1="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}-ycsb-run.txt"

submit_task ${1}
