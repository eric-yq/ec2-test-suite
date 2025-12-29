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

crank-agent &

## 下载 Benchmark 应用
cd /root/
git clone https://github.com/dotnet/crank.git 
git clone https://github.com/aspnet/Benchmarks.git

## sample : hello
SUT_IPADDR="172.31.93.195"
sed -i.bak "s/localhost/$SUT_IPADDR/g" crank/samples/hello/hello.benchmarks.yml
crank --config /root/crank/samples/hello/hello.benchmarks.yml --scenario hello --profile local

## sample : Mvc
cp /root/Benchmarks/src/BenchmarksApps/Mvc/benchmarks.crudapi.yml \
   /root/Benchmarks/src/BenchmarksApps/Mvc/benchmarks.crudapi.yml.bak
cd /root/Benchmarks/src/BenchmarksApps/Mvc/
cat << EOF >> benchmarks.crudapi.yml
profiles:
  local:
    variables:
      serverAddress: $SUT_IPADDR
    jobs: 
      application:
        endpoints: 
          - http://$SUT_IPADDR:5010
      load:
        endpoints: 
          - http://$SUT_IPADDR:5010
EOF

crank --config ./benchmarks.crudapi.yml \
      --scenario ApiCrudListProducts \
      --profile local \
      --application.source.localFolder $PWD/../../..
