#!/bin/bash

# Amazon Linux 2023

# 组网说明：
# 1. 在 Load Generator 上安装 crank 和 crank-agent，SUT 上只安装 crank-agent.
# 2. 在 Load Generator 上运行 crank 命令发起测试，crank-agent 负责在 Load Generator 和 SUT 上启动应用和负载生成器。

sudo su - root

yum install -y git aspnetcore-runtime-8.0 dotnet-runtime-8.0 dotnet-sdk-8.0 python3-pip
pip3 install dool

## 在 Load Generator 和 SUT 上都安装 Crank Controller 和 Agent
dotnet tool install -g Microsoft.Crank.Controller --version "0.2.0-*" 
dotnet tool install -g Microsoft.Crank.Agent --version "0.2.0-*"

cat << EOF >> ~/.bash_profile
# Add .NET Core SDK tools
export PATH="$PATH:/root/.dotnet/tools"
EOF
source ~/.bash_profile
nohup crank-agent &

## 下载 Benchmark 应用
cd /root/
git clone https://github.com/dotnet/crank.git 
git clone https://github.com/aspnet/Benchmarks.git

#########################################################################################################
## scenario : Mvc
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
        endpoints: "http://default-load:5010"
EOF

## 测试方式 1(Local)：Application 和 Load 在同一台机器上运行，
# SUT_IPADDR="172.31.91.179"
# SUT_INSTANCE="m7g.2xlarge"

SUT_IPADDR="172.31.88.38"
SUT_INSTANCE="m8g.2xlarge"

# SUT_IPADDR="172.31.91.116"
# SUT_INSTANCE="m9g-preview.2xlarge"

# SUT_IPADDR="172.31.90.44"
# SUT_INSTANCE="m8i.2xlarge"

let XXX=$(nproc)
crank --config ./benchmarks.crudapi.yml \
      --scenario ApiCrudListProducts \
      --profile my-profile \
      --application.source.localFolder $PWD/../../.. \
      --application.endpoints http://$SUT_IPADDR:5010 \
      --load.endpoints http://$SUT_IPADDR:5010 \
      --variable serverAddress=$SUT_IPADDR \
      --variable duration=60 \
      --variable connections=$XXX \
      --json results-local-crudapi-$SUT_INSTANCE-$SUT_IPADDR.json

#### 比较结果
crank compare results-local-crudapi-*.json

## 测试方式 2(Remote)：Application 和 Load 在两台不同的机器上运行
SUT_IPADDR="172.31.91.179"
SUT_INSTANCE="m7g.2xlarge"

SUT_IPADDR="172.31.88.38"
SUT_INSTANCE="m8g.2xlarge"

SUT_IPADDR="172.31.91.116"
SUT_INSTANCE="m9g-preview.2xlarge"

SUT_IPADDR="172.31.90.44"
SUT_INSTANCE="m8i.2xlarge"

let XXX=$(nproc)
crank --config ./benchmarks.crudapi.yml \
      --scenario ApiCrudListProducts \
      --profile my-profile \
      --application.source.localFolder $PWD/../../.. \
      --application.endpoints http://$SUT_IPADDR:5010 \
      --load.endpoints http://localhost:5010 \
      --variable serverAddress=$SUT_IPADDR \
      --variable duration=60 \
      --variable connections=$XXX \
      --json results-remote-crudapi-$SUT_INSTANCE-$SUT_IPADDR.json

#### 比较结果
crank compare results-remote-crudapi-*.json



#########################################################################################################
## scenario : blazor
### 报错：dotnet-install could not install a component: SDK '10.0.103'

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
        endpoints: "http://default-load:5010"
EOF

SUT_IPADDR="172.31.89.43"
SUT_INSTANCE="m8g.2xlarge"

let XXX=$(nproc)
crank --config ./blazor.benchmarks.yml \
      --scenario ssr \
      --profile my-profile \
      --application.endpoints http://$SUT_IPADDR:5010 \
      --load.endpoints http://$SUT_IPADDR:5010 \
      --variable duration=60 \
      --variable connections=$XXX \
      --json results-local-crudapi-$SUT_INSTANCE-$SUT_IPADDR.json