#!/bin/bash

## 使用方法： bash mongo-benchmark_v2.sh <IP地址>
## 按照线程数递增的方式测试 readonly，updateonly 和 mixed 等 workload

# set -e

submit_task(){

	if   [[ "$SUT_NAME" == "mongo" ]]; then
		
		SUT_IP_ADDR=${1}
		HOSTS="${SUT_IP_ADDR}:27017"   
		MONGO_URL=mongodb://root:gv2mongo@${HOSTS}/
	
	# elif  [[ "$SUT_NAME" == "mongo-replicaset" ]]; then
		
	# 	HOSTS="${INSTANCE_IP_MASTER}:27017,${INSTANCE_IP_SLAVE}:27017,${INSTANCE_IP_SLAVE1}:27017"
	# 	MONGO_URL=mongodb://root:gv2mongo@${HOSTS}/?replicaSet=rs0gv2mongo
    
    else 
    	
    	echo "Benchmark $SUT_NAME is not supported."
    	exit 1
    	
    fi
    
    ## Profile: workload_mongo
    THREAD_LIST="2 4 6 8 10 12 14 16 32"
    RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}-ycsb-load.txt"
    RESULT_FILE1="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}-ycsb-run.txt"

    ## 启动一个后台进程，执行dool命令，获取系统性能信息
    DOOL_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}_dool.txt"
    ssh -o StrictHostKeyChecking=no -i ~/ericyq-global.pem ec2-user@${SUT_IP_ADDR} \
    "dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60" \
    1> ${DOOL_FILE} 2>&1 &

	### 加载数据, load
	echo "[Info] Load data ..." >> ${RESULT_FILE}
	remove_database
	/root/ycsb-0.17.0/bin/ycsb load mongodb -P $(dirname $0)/workload_mongo_readonly -p mongodb.url=${MONGO_URL} \
		-threads $(nproc) >> ${RESULT_FILE}
		
    for i in ${THREAD_LIST}
    do
        ## 执行 Benchmark, run
        echo "[Info] This Test, current Thread=${i}: Run benchmark - Read only ..." >> ${RESULT_FILE1}
        /root/ycsb-0.17.0/bin/ycsb  run mongodb -P $(dirname $0)/workload_mongo_readonly -p mongodb.url=${MONGO_URL} \
            -threads ${i} >> ${RESULT_FILE1}
            
        echo "[Info] This Test, current Thread=${i}: Run benchmark - Update only ..." >> ${RESULT_FILE1}
        /root/ycsb-0.17.0/bin/ycsb  run mongodb -P $(dirname $0)/workload_mongo_updateonly -p mongodb.url=${MONGO_URL} \
            -threads ${i} >> ${RESULT_FILE1}
            
        # echo "[Info] This Test, current Thread=${i}: Run benchmark - Mixed(R:U:I=4:4:2) ..." >> ${RESULT_FILE1}
        # /root/ycsb-0.17.0/bin/ycsb  run mongodb -P $(dirname $0)/workload_mongo_rui -p mongodb.url=${MONGO_URL} \
        #     -threads ${i} >> ${RESULT_FILE1}
            
        echo "[Info] This Test, current Thread=${i}: Run benchmark - Mixed(Read 40%, Update 40%, Read-Modify-Write 20%) ..." >> ${RESULT_FILE1}
        /root/ycsb-0.17.0/bin/ycsb  run mongodb -P $(dirname $0)/workload_mongo_mixed -p mongodb.url=${MONGO_URL} \
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
rm -rf /data/mongodb/ycsb/ && ll /data/mongodb/
}

## 执行 benchmark 测试
source /tmp/temp-setting
RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}

submit_task ${1}

# ### 查看结果
# Load 结果数据：吞吐
# grep Throughput *load* | awk -F '[_ ]' '{print $2,$NF}'

# Run 结果数据：吞吐
