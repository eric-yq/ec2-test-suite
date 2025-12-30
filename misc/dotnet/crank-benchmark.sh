#!/bin/bash

# Amazon Linux 2023

sudo su - root

yum install -y git aspnetcore-runtime-8.0 dotnet-runtime-8.0 dotnet-sdk-8.0 

## 在 Load Generator 上安装 Crank Controller
dotnet tool install -g Microsoft.Crank.Controller --version "0.2.0-*" 

## 在 SUT 上安装 Crank agent
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

## sample : Mvc
cp /root/Benchmarks/src/BenchmarksApps/Mvc/benchmarks.crudapi.yml \
   /root/Benchmarks/src/BenchmarksApps/Mvc/benchmarks.crudapi.yml.bak
cd /root/Benchmarks/src/BenchmarksApps/Mvc/

SUT_IPADDR="172.31.4.109"
SUT_INSTANCE="c8i.xlarge"

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

SUT_IPADDR="172.31.10.199"
SUT_INSTANCE="c7g.xlarge"

SUT_IPADDR="172.31.15.192"
SUT_INSTANCE="c8g.xlarge"

SUT_IPADDR="172.31.4.109"
SUT_INSTANCE="c8i.xlarge"

## 测试方式 1：Application 和 Load 在同一台机器上运行
crank --config ./benchmarks.crudapi.yml \
      --scenario ApiCrudListProducts \
      --profile my-profile \
      --application.source.localFolder $PWD/../../.. \
      --application.endpoints http://$SUT_IPADDR:5010 \
      --load.endpoints http://$SUT_IPADDR:5010 \
      --variable serverAddress=$SUT_IPADDR \
      --variable duration=60 \
      --variable connections=4 \
      --json results-local-crudapi-$SUT_INSTANCE-$SUT_IPADDR.json

## 测试方式 2：Application 和 Load 在两台不同的机器上运行
crank --config ./benchmarks.crudapi.yml \
      --scenario ApiCrudListProducts \
      --profile my-profile \
      --application.source.localFolder $PWD/../../.. \
      --application.endpoints http://$SUT_IPADDR:5010 \
      --load.endpoints http://localhost:5010 \
      --variable serverAddress=$SUT_IPADDR \
      --variable duration=60 \
      --variable connections=4 \
      --json results-remote-crudapi-$SUT_INSTANCE-$SUT_IPADDR.json

## 比较多个结果
crank compare results-crudapi-*.json
