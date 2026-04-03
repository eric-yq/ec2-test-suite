#!/bin/bash

## 使用方法： bash milvus-benchmark.sh <IP地址>

# set -e

SUT_IP_ADDR=${1}
CASE_TYPE=${2:-Performance768D1M}
SUT_NAME="milvus"

## 执行 benchmark 测试
source /tmp/temp-setting

if [[ x"$INSTANCE_IP_MASTER" == x ]]; then
    INSTANCE_IP_MASTER=$SUT_IP_ADDR
fi

RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}_${CASE_TYPE}.txt"

## 启动一个后台进程，执行dool命令，获取系统性能信息
DOOL_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}_${CASE_TYPE}_dool-sut.txt"
ssh -o StrictHostKeyChecking=no -i ~/.aws/${KEY_NAME}.pem ec2-user@${SUT_IP_ADDR} \
  "dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60" \
  1>> ${DOOL_FILE} 2>&1 &
DOOL_FILE_LOADGEN="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}_${CASE_TYPE}_dool-loadgen.txt"
nohup dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60 \
  1>> ${DOOL_FILE_LOADGEN} 2>&1 &

echo "Test Detail on $(date)====================================================================================" >> ${RESULT_FILE}
echo "Start to perform test: SUT_IP_ADDR=${SUT_IP_ADDR}, CASE_TYPE=${CASE_TYPE}" >> ${RESULT_FILE}

# 设置数据集的保存目录
export DATASET_LOCAL_DIR="/root/vectordb_bench/dataset"
mkdir -p ${DATASET_LOCAL_DIR}

## 执行 benchmark
timestamp="$(date +%Y%m%d%H%M%S)"
vectordbbench milvushnsw \
  --case-type Performance768D1M \
  --m 30 --ef-construction 360 --ef-search 100 \
  --db-label milvusdb \
  --concurrency-duration 300 \
  --task-label milvus-${INSTANCE_TYPE}-${timestamp} \
  --uri http://${INSTANCE_IP_MASTER}:19530 1>>${RESULT_FILE} 2>&1

# cat /usr/local/lib/python3.13/site-packages/vectordb_bench/results/Milvus/result*milvus-${INSTANCE_TYPE}-${timestamp}*.json \
#   >> ${RESULT_FILE}
  
echo "Test End on $(date)================================================================" >> ${RESULT_FILE}
