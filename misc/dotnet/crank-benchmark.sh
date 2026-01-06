#!/bin/bash

# Amazon Linux 2023

# 组网说明：
# 1. 在 Load Generator 上安装 crank 和 crank-agent，SUT 上只安装 crank-agent.
# 2. 在 Load Generator 上运行 crank 命令发起测试，crank-agent 负责在 Load Generator 和 SUT 上启动应用和负载生成器。

sudo su - root

yum install -y aspnetcore-runtime-8.0 dotnet-runtime-8.0 dotnet-sdk-8.0 git yq python3-pip
pip3 install dool

## 在 Load Generator 和 SUT 上安装 Crank Controller 和 Agent
dotnet tool install -g Microsoft.Crank.Controller --version "0.2.0-*" 
dotnet tool install -g Microsoft.Crank.Agent --version "0.2.0-*"
cat << EOF >> ~/.bash_profile
# Add .NET Core SDK tools
export PATH="$PATH:/root/.dotnet/tools"
EOF
source ~/.bash_profile

# 启动 crank-agent：Applicaiton 和 Load 都需要运行 crank-agent
nohup crank-agent --url 'http://*:5010' > crank-agent-app.log 2>&1 &
nohup crank-agent --url 'http://*:5011' > crank-agent-load.log 2>&1 &

## 下载 Benchmark 应用
cd /root/
git clone https://github.com/dotnet/crank.git 
git clone https://github.com/aspnet/Benchmarks.git

#########################################################################################################
## scenario : Mvc CRUD API
cd /root/Benchmarks/src/BenchmarksApps/Mvc/
cp benchmarks.crudapi.yml benchmarks.crudapi.yml.bak

cat << EOF >> benchmarks.crudapi.yml

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

## 测试方式 1(Local)：Application 和 Load 在同一台机器上运行，
SUT_IPADDR="172.31.89.43"
APP_IPADDR=$SUT_IPADDR
LOAD_IPADDR=$SUT_IPADDR

## 测试方式 2(Remote)：Application 和 Load 在两台不同的机器上运行
## 使用crank controller 所在实例发起流量
# SUT_IPADDR="172.31.83.43"
# APP_IPADDR=$SUT_IPADDR
# LOAD_IPADDR=localhost

crank --config ./benchmarks.crudapi.yml \
      --scenario ApiCrudListProducts \
      --profile my-profile \
      --application.source.localFolder $PWD/../../.. \
      --application.endpoints http://$APP_IPADDR:5010 \
      --load.endpoints http://$LOAD_IPADDR:5011 \
      --variable serverAddress=$APP_IPADDR \
      --variable duration=60 \
      --variable connections=2

#### 比较结果
# crank compare *.json


#########################################################################################################
## scenario : Mvc jwtapi API
cd /root/Benchmarks/src/BenchmarksApps/Mvc/
cp benchmarks.jwtapi.yml benchmarks.jwtapi.yml.bak

cat << EOF >> benchmarks.jwtapi.yml

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

## 测试方式 1(Local)：Application 和 Load 在同一台机器上运行，
SUT_IPADDR="172.31.89.43"
APP_IPADDR=$SUT_IPADDR
LOAD_IPADDR=$SUT_IPADDR

## 测试方式 2(Remote)：Application 和 Load 在两台不同的机器上运行
## 使用crank controller 所在实例发起流量
# SUT_IPADDR="172.31.83.43"
# APP_IPADDR=$SUT_IPADDR
# LOAD_IPADDR=localhost

## 成功的场景： NoMvcAuth, NoMvcNoAuth, ApiCrudListProducts, ApiCrudGetProductDetails, ApiCrudUpdateProduct, ApiCrudDeleteProduct
## 报错的场景： NoMvcAsymmetricAuth, ApiCrudAddProduct

crank --config ./benchmarks.jwtapi.yml \
      --scenario ApiCrudDeleteProduct \
      --profile my-profile \
      --application.source.localFolder $PWD/../../.. \
      --application.endpoints http://$APP_IPADDR:5010 \
      --load.endpoints http://$LOAD_IPADDR:5011 \
      --variable serverAddress=$APP_IPADDR \
      --variable serverPort=5020 \
      --variable duration=60 \
      --variable connections=2


#########################################################################################################
## scenario : Mvc mvcjson 
cd /root/Benchmarks/src/BenchmarksApps/Mvc/
cp benchmarks.mvcjson.yml benchmarks.mvcjson.yml.bak

cat << EOF >> benchmarks.mvcjson.yml

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

## 测试方式 1(Local)：Application 和 Load 在同一台机器上运行，
SUT_IPADDR="172.31.89.43"
APP_IPADDR=$SUT_IPADDR
LOAD_IPADDR=$SUT_IPADDR

## 测试方式 2(Remote)：Application 和 Load 在两台不同的机器上运行
## 使用crank controller 所在实例发起流量
# SUT_IPADDR="172.31.83.43"
# APP_IPADDR=$SUT_IPADDR
# LOAD_IPADDR=localhost

## 成功的场景： MvcJson2k, MvcJsonOutput60k, MvcJsonOutput2M, MvcJsonInput2k, MvcJsonInput60k, MvcJsonInput2M,
## 报错的场景： MapActionEchoTodo MapActionEchoTodoForm

crank --config ./benchmarks.mvcjson.yml \
      --scenario MvcJsonOutput2M \
      --profile my-profile \
      --application.source.localFolder $PWD/../../.. \
      --application.endpoints http://$APP_IPADDR:5010 \
      --load.endpoints http://$LOAD_IPADDR:5011 \
      --variable serverAddress=$APP_IPADDR \
      --variable serverPort=5020 \
      --variable duration=60 \
      --variable connections=2 \
      --variable threads=2



#########################################################################################################
## scenario : blazor
### 报错：dotnet-install could not install a component: SDK '10.0.103'
### 根因：需要安装 .net 10

cd /root/Benchmarks/scenarios
cp blazor.benchmarks.yml blazor.benchmarks.yml.bak

cat << EOF >> blazor.benchmarks.yml

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

SUT_IPADDR="172.31.89.43"
APP_IPADDR=$SUT_IPADDR
LOAD_IPADDR=$SUT_IPADDR

let XXX=$(nproc)
crank --config ./blazor.benchmarks.yml \
      --scenario ssr \
      --profile my-profile \
      --application.endpoints http://$APP_IPADDR:5010 \
      --load.endpoints http://$LOAD_IPADDR:5011 \
      --variable duration=60 \
      --variable connections=$XXX