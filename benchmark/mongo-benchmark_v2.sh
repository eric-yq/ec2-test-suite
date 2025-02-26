#!/bin/bash

## 使用方法： bash mongo-benchmark_v2.sh <IP地址>
## 按照线程数递增的方式测试 readonly，updateonly 和 mixed 等 workload

# set -e

submit_task(){

	if   [[ "$SUT_NAME" == "mongo" ]]; then
		
		SUT_IP_ADDR=${1}
		HOSTS="${SUT_IP_ADDR}:27017"   
		MONGO_URL=mongodb://root:gv2mongo@${HOSTS}/
	
	elif  [[ "$SUT_NAME" == "mongo-replicaset" ]]; then
		
		HOSTS="${INSTANCE_IP_MASTER}:27017,${INSTANCE_IP_SLAVE}:27017,${INSTANCE_IP_SLAVE1}:27017"
		MONGO_URL=mongodb://root:gv2mongo@${HOSTS}/?replicaSet=rs0gv2mongo
    
    else 
    	
    	echo "Benchmark $SUT_NAME is not supported."
    	exit 1
    	
    fi
    
    ## Profile: workload_mongo
#   THREAD_LIST="16 32 48 64 80 96 112 128 144 160 176 192"
#     THREAD_LIST="1 2 4 6 8 12 16 32 48 64 80 96"
    THREAD_LIST="2 4 6 8 10 12 14 16 32"
#     THREAD_LIST="1"
    RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}-ycsb-load.txt"
    RESULT_FILE1="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}-ycsb-run.txt"

	### 加载数据, load
	echo "[Info] Load data ..." >> ${RESULT_FILE}
	remove_database
	/root/ycsb-0.17.0/bin/ycsb load mongodb -P $(dirname $0)/workload_mongo_readonly -p mongodb.url=${MONGO_URL} \
		-threads $(nproc) >> ${RESULT_FILE}
		
    for i in ${THREAD_LIST}
    do
        ### 执行 Benchmark, run
#         echo "[Info] This Test, current Thread=${i}: Run benchmark - Read only ..." >> ${RESULT_FILE1}
#         /root/ycsb-0.17.0/bin/ycsb  run mongodb -P $(dirname $0)/workload_mongo_readonly -p mongodb.url=${MONGO_URL} \
#             -threads ${i} >> ${RESULT_FILE1}
#             
#         echo "[Info] This Test, current Thread=${i}: Run benchmark - Update only ..." >> ${RESULT_FILE1}
#         /root/ycsb-0.17.0/bin/ycsb  run mongodb -P $(dirname $0)/workload_mongo_updateonly -p mongodb.url=${MONGO_URL} \
#             -threads ${i} >> ${RESULT_FILE1}
            
        echo "[Info] This Test, current Thread=${i}: Run benchmark - Mixed(R:U:I=4:4:2) ..." >> ${RESULT_FILE1}
        /root/ycsb-0.17.0/bin/ycsb  run mongodb -P $(dirname $0)/workload_mongo_rui -p mongodb.url=${MONGO_URL} \
            -threads ${i} >> ${RESULT_FILE1}
            
#         echo "[Info] This Test, current Thread=${i}: Run benchmark - Mixed(100% Read-Modify-Write) ..." >> ${RESULT_FILE1}
#         /root/ycsb-0.17.0/bin/ycsb  run mongodb -P $(dirname $0)/workload_mongo_mixed -p mongodb.url=${MONGO_URL} \
#             -threads ${i} >> ${RESULT_FILE1} 
    
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

### 查看结果
# Load 结果数据：吞吐
grep Throughput *load* ｜ awk -F"," '{print $3}'
grep INSERT *load* | grep AverageLatency ｜ awk -F"," '{print $3}'
grep INSERT *load* | grep 99thPercentileLatency ｜ awk -F"," '{print $3}'
# Run 结果数据：时延
## readonly 平均和P99时延，打印1/4/7......行(每隔3行)
grep AverageLatency mongo_*-run.txt | grep READ  | sed -n '1~3p' | awk -F", " '{print $3}'
grep 99thPercentileLatency mongo_*-run.txt | grep READ  | sed -n '1~3p' | awk -F", " '{print $3}'
## updateonly 平均和P99时延，打印1/3/5......行(每隔2行)
grep AverageLatency mongo_*-run.txt | grep UPDATE  | sed -n '1~2p' | awk -F", " '{print $3}'
grep 99thPercentileLatency mongo_*-run.txt | grep UPDATE  | sed -n '1~2p' | awk -F", " '{print $3}'
## read-modify-write 平均和P99时延
grep AverageLatency mongo_*-run.txt | grep MODIFY | awk -F", " '{print $3}'
grep 99thPercentileLatency mongo_*-run.txt | grep MODIFY | awk -F", " '{print $3}'



# ## 计算平均值: 3 副本：5 个机型，每个机型测试 3 次。
# ### load 吞吐
# instance_type_array=($(grep Throughput *load* | awk -F "_" '{print $2}' | uniq))
# ops_array=($(grep Throughput *load* | awk -F "," '{print $NF}' | awk -F "." '{print $1}'))
# latency_array_avg=($(grep AverageLatency *load* | grep INSERT  | awk -F "," '{print $NF}' | awk -F "." '{print $1}'))
# latency_array_p95=($(grep 95thPercentileLatency *load* | grep INSERT  | awk -F "," '{print $NF}' | awk -F "." '{print $1}'))
# latency_array_p99=($(grep 99thPercentileLatency *load* | grep INSERT  | awk -F "," '{print $NF}' | awk -F "." '{print $1}'))
# for i in {1..5}
# do
#     let base=3*(i-1)
#     let ops_avg=(${ops_array[base]}+${ops_array[base+1]}+${ops_array[base+2]})/3
#     let latency_avg=(${latency_array_avg[base]}+${latency_array_avg[base+1]}+${latency_array_avg[base+2]})/3
#     let p95_avg=(${latency_array_p95[base]}+${latency_array_p95[base+1]}+${latency_array_p95[base+2]})/3
#     let p99_avg=(${latency_array_p99[base]}+${latency_array_p99[base+1]}+${latency_array_p99[base+2]})/3
#     echo "${instance_type_array[i-1]},${ops_avg},${latency_avg},${p95_avg},${p99_avg}"
# done

