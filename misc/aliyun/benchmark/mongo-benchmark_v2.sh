#!/bin/bash

## 使用方法： bash mongo-benchmark_v2.sh <IP地址>
## 按照线程数递增的方式测试 readonly，updateonly 和 mixed 等 workload

# set -e

submit_task(){
    SUT_IP_ADDR=${1}
    HOSTS="${SUT_IP_ADDR}:27017"   
    MONGO_URL=mongodb://root:gv2mongo@${HOSTS}/

    SUT_NAME="mongo"
    OS_TYPE="alinux3"
    INSTANCE_TYPE=$(sshpass -p '3k3j9knjM' ssh -o StrictHostKeyChecking=no root@$SUT_IP_ADDR "cloud-init query ds.meta-data.instance.instance-type")

    ## Profile: workload_mongo
    THREAD_LIST="2 4 6 8 10 12 14 16 32"
    RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}-ycsb-load.txt"
    RESULT_FILE1="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}-ycsb-run.txt"

    ## 启动一个后台进程，执行dool命令，获取系统性能信息
    DOOL_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}_dool.txt"
    sshpass -p '3k3j9knjM' ssh -o StrictHostKeyChecking=no root@${SUT_IP_ADDR} \
    "dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60 720" \
    1> ${DOOL_FILE} 2>&1 &

	### 加载数据, load
	echo "[Info] Load data ..." >> ${RESULT_FILE}
	remove_database

	python2 /root/ycsb-0.17.0/bin/ycsb load mongodb -P $(dirname $0)/workload_mongo_readonly -p mongodb.url=${MONGO_URL} \
		-threads $(nproc) >> ${RESULT_FILE}
		
    for i in ${THREAD_LIST}
    do
        ## 执行 Benchmark, run
        echo "[Info] This Test, current Thread=${i}: Run benchmark - Read only ..." >> ${RESULT_FILE1}
        python2 /root/ycsb-0.17.0/bin/ycsb  run mongodb -P $(dirname $0)/workload_mongo_readonly -p mongodb.url=${MONGO_URL} \
            -threads ${i} >> ${RESULT_FILE1} 
            
        echo "[Info] This Test, current Thread=${i}: Run benchmark - Update only ..." >> ${RESULT_FILE1}
        python2 /root/ycsb-0.17.0/bin/ycsb  run mongodb -P $(dirname $0)/workload_mongo_updateonly -p mongodb.url=${MONGO_URL} \
            -threads ${i} >> ${RESULT_FILE1}
            
        echo "[Info] This Test, current Thread=${i}: Run benchmark - Mixed(Read 40%, Update 40%, Read-Modify-Write 20%) ..." >> ${RESULT_FILE1}
        python2 /root/ycsb-0.17.0/bin/ycsb  run mongodb -P $(dirname $0)/workload_mongo_mixed -p mongodb.url=${MONGO_URL} \
            -threads ${i} >> ${RESULT_FILE1} 
    
        ### 完成测试后删除数据库
        # remove_database && \
        echo "[Info] This is Test-${i}: All benchmark tests completed." >> ${RESULT_FILE1}
        sleep 30
    done
}

remove_database(){
    mongosh ${MONGO_URL} << EOF
use ycsb
db.dropDatabase()
EOF
    rm -rf /data/mongodb/ycsb/
}

## 执行 benchmark 测试
# source /tmp/temp-setting
RESULT_PATH="/root/benchmark-result-files"
mkdir -p ${RESULT_PATH}



submit_task ${1}
