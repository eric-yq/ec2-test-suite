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
DOOL_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}_dool-sut.txt"
ssh -o StrictHostKeyChecking=no -i ~/ericyq-global.pem ec2-user@${SUT_IP_ADDR} \
  "dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 5" \
  1> ${DOOL_FILE} 2>&1 &
DOOL_FILE_LOADGEN="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}_dool-loadgen.txt"
nohup dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 5 \
  1> ${DOOL_FILE_LOADGEN} 2>&1 &

## 下载 Benchmark 应用
cd /root/
rm -rf /root/Benchmarks
git clone https://github.com/aspnet/Benchmarks.git

# 设置 APP 和 LOAD 在同一个机器上运行
APP_IPADDR=$SUT_IP_ADDR
LOAD_IPADDR=$APP_IPADDR
DB_IPADDR=$APP_IPADDR

# 定制一个 profile 文件
cat << EOF > /root/Benchmarks/my-custom-profiles.yml
profiles:
  my-profile:
    variables:
      serverAddress: default-app
    jobs:
      application:
        endpoints: "http://default-app:5010"
      load:
        endpoints: "http://default-load:5011"
      db:
        endpoints: "http://default-db:5012"
EOF

###########################################################################################################
## 测试1: Mvc, crudapi
APPNAME="Mvc"
CONFIG="benchmarks.crudapi.yml"
SCENARIOS="ApiCrudListProducts ApiCrudGetProductDetails ApiCrudAddProduct ApiCrudUpdateProduct ApiCrudDeleteProduct"
DURATION=60
CONN=4
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}_${APPNAME}_${CONFIG}.txt"

cd /root/Benchmarks/src/BenchmarksApps/$APPNAME/

# 执行各个场景
for SCENARIO in $SCENARIOS
do
    echo "Processing Application: $APNAME, Config: $CONFIG, Scenario: $SCENARIO ..." >> ${RESULT_FILE}
    # 获取该 scenario 的详细信息
    crank --config ./$CONFIG \
      --config /root/Benchmarks/my-custom-profiles.yml \
      --profile my-profile \
      --scenario $SCENARIO \
      --application.source.localFolder $PWD/../../.. \
      --application.endpoints http://$APP_IPADDR:5010 \
      --load.endpoints http://$LOAD_IPADDR:5011 \
      --variable serverAddress=$APP_IPADDR \
      --variable duration=$DURATION \
      --variable connections=$CONN 1>>${RESULT_FILE} 2>&1
done

###########################################################################################################
## 测试2: Mvc, jwtapi
APPNAME="Mvc"
CONFIG="benchmarks.jwtapi.yml"
SCENARIOS="Auth NoMvcNoAuth ApiCrudListProducts ApiCrudGetProductDetails ApiCrudUpdateProduct ApiCrudDeleteProduct"
DURATION=60
CONN=2
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}_${APPNAME}_${CONFIG}.txt"

cd /root/Benchmarks/src/BenchmarksApps/$APPNAME/

# 执行各个场景
for SCENARIO in $SCENARIOS
do
    echo "Processing Application: $APNAME, Config: $CONFIG, Scenario: $SCENARIO ..." >> ${RESULT_FILE}
    # 获取该 scenario 的详细信息
    crank --config ./$CONFIG \
      --config /root/Benchmarks/my-custom-profiles.yml \
      --profile my-profile \
      --scenario $SCENARIO \
      --application.source.localFolder $PWD/../../.. \
      --application.endpoints http://$APP_IPADDR:5010 \
      --load.endpoints http://$LOAD_IPADDR:5011 \
      --variable serverAddress=$APP_IPADDR \
      --variable serverPort=5020 \
      --variable duration=$DURATION \
      --variable connections=$CONN 1>>${RESULT_FILE} 2>&1
done

###########################################################################################################
## 测试3: Mvc, mvcjson
APPNAME="Mvc"
CONFIG="benchmarks.mvcjson.yml"
SCENARIOS="MvcJson2k MvcJsonOutput60k MvcJsonOutput2M MvcJsonInput2k MvcJsonInput60k MvcJsonInput2M"
DURATION=60
CONN=2
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}_${APPNAME}_${CONFIG}.txt"

cd /root/Benchmarks/src/BenchmarksApps/$APPNAME/

# 执行各个场景
for SCENARIO in $SCENARIOS
do
    echo "Processing Application: $APNAME, Config: $CONFIG, Scenario: $SCENARIO ..." >> ${RESULT_FILE}
    # 获取该 scenario 的详细信息
    crank --config ./$CONFIG \
      --config /root/Benchmarks/my-custom-profiles.yml \
      --profile my-profile \
      --scenario $SCENARIO \
      --application.source.localFolder $PWD/../../.. \
      --application.endpoints http://$APP_IPADDR:5010 \
      --load.endpoints http://$LOAD_IPADDR:5011 \
      --variable serverAddress=$APP_IPADDR \
      --variable serverPort=5020 \
      --variable duration=$DURATION \
      --variable connections=$CONN \
      --variable threads=$CONN \
      1>>${RESULT_FILE} 2>&1
done

###########################################################################################################
## 测试4: TechEmpower, BlazorSSR
APPNAME="TechEmpower"
CONFIG="blazorssr.benchmarks.yml"
SCENARIOS="fortunes fortunes-ef fortunes-direct fortunes-direct-ef fortunes-direct-params"
DURATION=60
CONN=2
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}_${APPNAME}_${CONFIG}.txt"

cd /root/Benchmarks/src/BenchmarksApps/$APPNAME/BlazorSSR

# 执行各个场景
for SCENARIO in $SCENARIOS
do
    echo "Processing Application: $APNAME, Config: $CONFIG, Scenario: $SCENARIO ..." >> ${RESULT_FILE}
    # 获取该 scenario 的详细信息
    crank --config ./$CONFIG \
      --config /root/Benchmarks/my-custom-profiles.yml \
      --profile my-profile \
      --scenario $SCENARIO \
      --application.endpoints http://$APP_IPADDR:5010 \
      --load.endpoints http://$LOAD_IPADDR:5011 \
      --db.endpoints http://$APP_IPADDR:5012 \
      --variable serverAddress=$APP_IPADDR \
      --variable serverPort=5020 \
      --variable databaseServer=$APP_IPADDR \
      --variable duration=$DURATION \
      --variable connections=$CONN \
      --variable threads=$CONN \
      1>>${RESULT_FILE} 2>&1
done

###########################################################################################################
## 测试5: TechEmpower, RazorPages
APPNAME="TechEmpower"
CONFIG="razorpages.benchmarks.yml"
# SCENARIOS="fortunes fortunes-ef"
SCENARIOS="fortunes"
DURATION=60
CONN=2
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}_${APPNAME}_${CONFIG}.txt"

cd /root/Benchmarks/src/BenchmarksApps/$APPNAME/RazorPages
### Pages 目录下 /fortunes-ef 路径有问题，做个替换
sed -i.bak 's/path: \/fortunes-ef/path: \/fortunesef/g' $CONFIG

# 执行各个场景
for SCENARIO in $SCENARIOS
do
    echo "Processing Application: $APNAME, Config: $CONFIG, Scenario: $SCENARIO ..." >> ${RESULT_FILE}
    # 获取该 scenario 的详细信息
    crank --config ./$CONFIG \
      --config /root/Benchmarks/my-custom-profiles.yml \
      --profile my-profile \
      --scenario $SCENARIO \
      --application.endpoints http://$APP_IPADDR:5010 \
      --load.endpoints http://$LOAD_IPADDR:5011 \
      --db.endpoints http://$DB_IPADDR:5012 \
      --variable serverAddress=$APP_IPADDR \
      --variable serverPort=5020 \
      --variable databaseServer=$DB_IPADDR \
      --variable duration=$DURATION \
      --variable connections=$CONN \
      --variable threads=$CONN \
      1>>${RESULT_FILE} 2>&1
done

###########################################################################################################
## 测试6: TechEmpower, Mvc
APPNAME="TechEmpower"
CONFIG="mvc.benchmarks.yml"
DURATION=60
CONN=2
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}_${APPNAME}_${CONFIG}.txt"

cd /root/Benchmarks/src/BenchmarksApps/$APPNAME/Mvc

# 执行各个场景：不需要 DB 的
SCENARIOS="plaintext json"
for SCENARIO in $SCENARIOS
do
    echo "Processing Application: $APNAME, Config: $CONFIG, Scenario: $SCENARIO ..." >> ${RESULT_FILE}
    # 获取该 scenario 的详细信息
    crank --config ./$CONFIG \
      --config /root/Benchmarks/my-custom-profiles.yml \
      --profile my-profile \
      --scenario $SCENARIO \
      --application.endpoints http://$APP_IPADDR:5010 \
      --load.endpoints http://$LOAD_IPADDR:5011 \
      --variable serverAddress=$APP_IPADDR \
      --variable serverPort=5020 \
      --variable duration=$DURATION \
      --variable connections=$CONN \
      --variable threads=$CONN \
      1>>${RESULT_FILE} 2>&1
done

# 执行各个场景：需要 DB 的
SCENARIOS="fortunes fortunes_dapper single_query multiple_queries updates"
for SCENARIO in $SCENARIOS
do
    echo "Processing Application: $APNAME, Config: $CONFIG, Scenario: $SCENARIO ..." >> ${RESULT_FILE}
    # 获取该 scenario 的详细信息
    crank --config ./$CONFIG \
      --config /root/Benchmarks/my-custom-profiles.yml \
      --profile my-profile \
      --scenario $SCENARIO \
      --application.endpoints http://$APP_IPADDR:5010 \
      --load.endpoints http://$LOAD_IPADDR:5011 \
      --db.endpoints http://$APP_IPADDR:5012 \
      --variable serverAddress=$APP_IPADDR \
      --variable serverPort=5020 \
      --variable databaseServer=$DB_IPADDR \
      --variable duration=$DURATION \
      --variable connections=$CONN \
      --variable threads=$CONN \
      1>>${RESULT_FILE} 2>&1
done

# 停止 dool 监控
sleep 10 && killall ssh dool