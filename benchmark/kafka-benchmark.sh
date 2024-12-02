#!/bin/bash

## 使用方法： bash kafka-benchmark.sh <IP地址> <消息数>

SUT_IP_ADDR=${1}
NUM_RECORDS=${2}
# NUM_RECORDS=100000000


source /tmp/temp-setting
RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}.txt"

SERVERS="${INSTANCE_IP_MASTER}:9092"
OPTS="${SERVERS} --partitions 8 --replication-factor 1 "
if [[ ${SUT_NAME} == "kafka-cluster" ]]; then
    SERVERS="${INSTANCE_IP_MASTER}:9092,${INSTANCE_IP_SLAVE}:9092,${INSTANCE_IP_SLAVE1}:9092"
	OPTS="${SERVERS} --partitions 8 --replication-factor 3"
fi

### Benchmark test
source /etc/profile

## 创建 topic
kafka-topics.sh --create --topic kafka-load-test --bootstrap-server ${OPTS} 

## producer load test
echo "Start producer load test: $(date)"
echo ">>> producer load test results: " >> ${RESULT_FILE}.summary
for i in {1..8}
do
	kafka-producer-perf-test.sh --topic kafka-load-test \
	  --num-records ${NUM_RECORDS} --throughput -1 --record-size 1024 \
	  --producer-props bootstrap.servers=${SERVERS} acks=1 linger.ms=3 buffer.memory=128000000 \
	   batch.size=123456 compression.type=lz4  >> ${RESULT_FILE}.${i} &
done 

## 等待 producer load test 完成
wait

grep 99th ${RESULT_FILE}.? >> ${RESULT_FILE}.summary
rm -rf ${RESULT_FILE}.?
# cat  ${RESULT_FILE}.summary
echo "Complete producer load test: $(date)"

## consumer load test
echo "Start consumer load test: $(date)"
echo ">>> consumer load test results: " >> ${RESULT_FILE}.summary
kafka-consumer-perf-test.sh --topic kafka-load-test --timeout 6000000 \
  --bootstrap-server ${SERVERS} --messages 50000000 >> ${RESULT_FILE}.summary

cat  ${RESULT_FILE}.summary
echo "Complete consumer load test: $(date)"


  
