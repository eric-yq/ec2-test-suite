#!/bin/bash

## 使用方法： bash milvus-benchmark.sh <IP地址>

# set -e

SUT_IP_ADDR=${1}
CASE_TYPE=${2}
SUT_NAME="milvus"

INSTANCE_TYPE=$(ec2-metadata --quiet --instance-type)
OS_TYPE=al2023

RESULT_PATH="/root/benchmark-result-files"
mkdir -p ${RESULT_PATH}
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}_${CASE_TYPE}.txt"

## 启动一个后台进程，执行dool命令，获取系统性能信息
DOOL_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${SUT_IP_ADDR}_${CASE_TYPE}_dool-sut.txt"
dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60 1>> ${DOOL_FILE} 2>&1 &

echo "Test Detail on $(date)====================================================================================" >> ${RESULT_FILE}
echo "Start to perform test: SUT_IP_ADDR=${1}, CASE_TYPE=${2}" >> ${RESULT_FILE}

## 执行 benchmark
timestamp="$(date +%Y%m%d%H%M%S)"
vectordbbench milvushnsw \
  --case-type ${CASE_TYPE} \
  --m 30 --ef-construction 360 --ef-search 100 \
  --db-label milvusdb \
  --concurrency-duration 300 \
  --task-label milvus-${INSTANCE_TYPE}-${timestamp} \
  --uri http://${INSTANCE_IP_MASTER}:19530 1>>${RESULT_FILE} 2>&1

cat /usr/local/lib/python3.13/site-packages/vectordb_bench/results/Milvus/result*milvus-${INSTANCE_TYPE}-${timestamp}*.json \
  >> ${RESULT_FILE}
  
echo "Test End on $(date)====================================================================================" >> ${RESULT_FILE}
