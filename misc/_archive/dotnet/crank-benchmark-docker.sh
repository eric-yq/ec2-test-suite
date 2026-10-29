#!/bin/bash

# Amazon Linux 2023

# 组网说明：
# 1. 在 Load Generator 上安装 crank 和 crank-agent，SUT 上只安装 crank-agent.
# 2. 在 Load Generator 上运行 crank 命令发起测试，crank-agent 负责在 Load Generator 和 SUT 上启动应用和负载生成器。

sudo su - root

yum install -y git aspnetcore-runtime-8.0 dotnet-runtime-8.0 dotnet-sdk-8.0 python3-pip
pip3 install dool

# 安装 .net10.0 
# curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --version latest --channel 10.0

## 在 Load Generator 和 SUT 上安装 Crank Controller 和 Agent
dotnet tool install -g Microsoft.Crank.Controller --version "0.2.0-*" 
dotnet tool install -g Microsoft.Crank.Agent --version "0.2.0-*"
cat << EOF >> ~/.bash_profile
# Add .NET Core SDK tools
export PATH="$PATH:/root/.dotnet/tools"
EOF
source ~/.bash_profile
# 启动 crank-agent：Applicaiton 和 Load 都需要运行 crank-agent
# nohup crank-agent --url 'http://*:5010' > crank-agent-app.log 2>&1 &
# nohup crank-agent --url 'http://*:5011' > crank-agent-load.log 2>&1 &

## 在 SUT 上通过容器的方式运行 crank-agent
yum install -y git python3-pip libicu docker
systemctl start docker
systemctl enable docker
mkdir ~/src
cd ~/src
git clone https://github.com/dotnet/crank
cd ~/src/crank/docker/agent
./build.sh
./run.sh
。/stop.sh

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
        endpoints: "http://default-load:5011"
EOF

## 测试方式 1(Local)：Application 和 Load 在同一台机器上运行，
SUT_IPADDR="172.31.83.192"
SUT_INSTANCE="m8g.2xlarge"

let XXX=$(nproc)
crank --config ./benchmarks.crudapi.yml \
      --scenario ApiCrudListProducts \
      --profile my-profile \
      --application.source.localFolder $PWD/../../.. \
      --application.endpoints http://$SUT_IPADDR:5010 \
      --load.endpoints http://$SUT_IPADDR:5010 \
      --variable serverAddress=$SUT_IPADDR \
      --variable duration=60 \
      --variable connections=$XXX 

#### 比较结果
crank compare results-local-crudapi-*.json

## 测试方式 2(Remote)：Application 和 Load 在两台不同的机器上运行
SUT_IPADDR="172.31.83.192"
SUT_INSTANCE="m8g.2xlarge"

let XXX=$(nproc)
crank --config ./benchmarks.crudapi.yml \
      --scenario ApiCrudListProducts \
      --profile my-profile \
      --application.source.localFolder $PWD/../../.. \
      --application.endpoints http://$SUT_IPADDR:5010 \
      --load.endpoints http://localhost:5010 \
      --variable serverAddress=$SUT_IPADDR \
      --variable duration=60 \
      --variable connections=$XXX 

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

SUT_IPADDR="172.31.83.192"
SUT_INSTANCE="m8g.2xlarge"

let XXX=$(nproc)
crank --config ./blazor.benchmarks.yml \
      --scenario ssr \
      --profile my-profile \
      --application.endpoints http://$SUT_IPADDR:5010 \
      --load.endpoints http://$SUT_IPADDR:5010 \
      --variable duration=60 \
      --variable connections=$XXX