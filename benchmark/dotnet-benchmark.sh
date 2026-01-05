#!/bin/bash

## 使用方法： bash dotnet-benchmark.sh <IP地址>

# set -e

SUT_IP_ADDR=${1}
SUT_NAME="dotnet"

## 执行 benchmark 测试
source /tmp/temp-setting

if [[ x"$INSTANCE_IP_MASTER" == x ]]; then
    INSTANCE_IP_MASTER=$SUT_IP_ADDR
fi

RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}

## 启动一个后台进程，执行dool命令，获取系统性能信息
DOOL_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}_dool.txt"
ssh -o StrictHostKeyChecking=no -i ~/ericyq-global.pem ec2-user@${SUT_IP_ADDR} \
  "dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 5 360" \
  1> ${DOOL_FILE} 2>&1 &

## 下载 Benchmark 应用
cd /root/
rm -rf /root/Benchmarks
git clone https://github.com/aspnet/Benchmarks.git

## BenchmarkApp : Mvc
APPNAME="Mvc"
CONFIG="benchmarks.crudapi.yml"
DURATION=60
CONN=4
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}_${APPNAME}.txt"

echo "Start to perform test: SUT_IP_ADDR=$SUT_IP_ADDR, Applicaiton=$APPNAME, " >> ${RESULT_FILE}
cd /root/Benchmarks/src/BenchmarksApps/$APPNAME/
cp $CONFIG $CONFIG.bak
cat << EOF >> $CONFIG

profiles:
  my-profile:
    variables:
      serverAddress: default-app
    jobs:
      application:
        endpoints: "http://default-app:5010"
      load:
        endpoints: "http://default-load:5011"
EOF

APP_IPADDR=$SUT_IP_ADDR
LOAD_IPADDR=$APP_IPADDR

# 执行其中包含的各个场景
yq '.scenarios | keys[]' $CONFIG | while read SCENARIO; do
    echo "Processing scenario: $SCENARIO" >> ${RESULT_FILE}
    # 获取该 scenario 的详细信息
    crank --config ./$CONFIG \
      --scenario $SCENARIO \
      --profile my-profile \
      --application.source.localFolder $PWD/../../.. \
      --application.endpoints http://$APP_IPADDR:5010 \
      --load.endpoints http://$LOAD_IPADDR:5011 \
      --variable serverAddress=$APP_IPADDR \
      --variable duration=$DURATION \
      --variable connections=$CONN 1>>${RESULT_FILE} 2>&1
done
