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

crank --config ./benchmarks.crudapi.yml \
      --scenario ApiCrudListProducts \
      --profile my-profile \
      --application.source.localFolder $PWD/../../.. \
      --application.endpoints http://$SUT_IPADDR:5010 \
      --load.endpoints http://$SUT_IPADDR:5010 \
      --variable serverAddress=$SUT_IPADDR \
      --variable duration=60 \
      --variable connections=4 \
      --json results-crudapi-$SUT_INSTANCE-$SUT_IPADDR.json

## 查看结果: c7g.xlarge
| application               |                     |
| ------------------------- | ------------------- |
| Max Process CPU Usage (%) | 100                 |
| Max Cores usage (%)       | 399                 |
| Max Working Set (MB)      | 182                 |
| Max Private Memory (MB)   | 288                 |
| Build Time (ms)           | 6,142               |
| Start Time (ms)           | 229                 |
| Published Size (KB)       | 108,094             |
| Symbols Size (KB)         | 24                  |
| .NET Core SDK Version     | 8.0.416             |
| ASP.NET Core Version      | 8.0.22+ee4174799332 |
| .NET Runtime Version      | 8.0.22+a2266c728f63 |
| Max Global CPU Usage (%)  | 100                 |


| load                      |                     |
| ------------------------- | ------------------- |
| Max Process CPU Usage (%) | 19                  |
| Max Cores usage (%)       | 151                 |
| Max Working Set (MB)      | 47                  |
| Max Private Memory (MB)   | 136                 |
| Build Time (ms)           | 3,569               |
| Start Time (ms)           | 96                  |
| Published Size (KB)       | 72,281              |
| Symbols Size (KB)         | 0                   |
| .NET Core SDK Version     | 8.0.416             |
| ASP.NET Core Version      | 8.0.22+ee4174799332 |
| .NET Runtime Version      | 8.0.22+a2266c728f63 |
| Max Global CPU Usage (%)  | 23                  |
| First Request (ms)        | 137                 |
| Requests                  | 4,104,067           |
| Bad responses             | 0                   |
| Latency 50th (ms)         | 0.22                |
| Latency 75th (ms)         | 0.26                |
| Latency 90th (ms)         | 0.30                |
| Latency 95th (ms)         | 0.33                |
| Latency 99th (ms)         | 0.41                |
| Mean latency (ms)         | 0.23                |
| Max latency (ms)          | 11.77               |
| Requests/sec              | 68,402              |
| Requests/sec (max)        | 76,536              |
| Read throughput (MB/s)    | 246.06              |

## 查看结果: c8g.xlarge
| application               |                     |
| ------------------------- | ------------------- |
| Max Process CPU Usage (%) | 100                 |
| Max Cores usage (%)       | 399                 |
| Max Working Set (MB)      | 187                 |
| Max Private Memory (MB)   | 301                 |
| Build Time (ms)           | 4,814               |
| Start Time (ms)           | 189                 |
| Published Size (KB)       | 108,240             |
| Symbols Size (KB)         | 24                  |
| .NET Core SDK Version     | 8.0.416             |
| ASP.NET Core Version      | 8.0.22+ee4174799332 |
| .NET Runtime Version      | 8.0.22+a2266c728f63 |
| Max Global CPU Usage (%)  | 100                 |


| load                      |                     |
| ------------------------- | ------------------- |
| Max Process CPU Usage (%) | 24                  |
| Max Cores usage (%)       | 194                 |
| Max Working Set (MB)      | 47                  |
| Max Private Memory (MB)   | 135                 |
| Build Time (ms)           | 3,530               |
| Start Time (ms)           | 67                  |
| Published Size (KB)       | 72,281              |
| Symbols Size (KB)         | 0                   |
| .NET Core SDK Version     | 8.0.416             |
| ASP.NET Core Version      | 8.0.22+ee4174799332 |
| .NET Runtime Version      | 8.0.22+a2266c728f63 |
| Max Global CPU Usage (%)  | 26                  |
| First Request (ms)        | 111                 |
| Requests                  | 5,290,620           |
| Bad responses             | 0                   |
| Latency 50th (ms)         | 0.17                |
| Latency 75th (ms)         | 0.21                |
| Latency 90th (ms)         | 0.24                |
| Latency 95th (ms)         | 0.26                |
| Latency 99th (ms)         | 0.33                |
| Mean latency (ms)         | 0.18                |
| Max latency (ms)          | 14.81               |
| Requests/sec              | 88,177              |
| Requests/sec (max)        | 100,357             |
| Read throughput (MB/s)    | 317.19              |


##  查看结果: c8i.xlarge
| application               |                     |
| ------------------------- | ------------------- |
| Max Process CPU Usage (%) | 98                  |
| Max Cores usage (%)       | 391                 |
| Max Working Set (MB)      | 1,286               |
| Max Private Memory (MB)   | 1,413               |
| Build Time (ms)           | 4,098               |
| Start Time (ms)           | 231                 |
| Published Size (KB)       | 99,385              |
| Symbols Size (KB)         | 24                  |
| .NET Core SDK Version     | 8.0.416             |
| ASP.NET Core Version      | 8.0.22+ee4174799332 |
| .NET Runtime Version      | 8.0.22+a2266c728f63 |
| Max Global CPU Usage (%)  | 98                  |


| load                      |                     |
| ------------------------- | ------------------- |
| Max Process CPU Usage (%) | 18                  |
| Max Cores usage (%)       | 146                 |
| Max Working Set (MB)      | 47                  |
| Max Private Memory (MB)   | 135                 |
| Build Time (ms)           | 3,520               |
| Start Time (ms)           | 77                  |
| Published Size (KB)       | 72,281              |
| Symbols Size (KB)         | 0                   |
| .NET Core SDK Version     | 8.0.416             |
| ASP.NET Core Version      | 8.0.22+ee4174799332 |
| .NET Runtime Version      | 8.0.22+a2266c728f63 |
| Max Global CPU Usage (%)  | 20                  |
| First Request (ms)        | 106                 |
| Requests                  | 3,656,422           |
| Bad responses             | 0                   |
| Latency 50th (ms)         | 0.25                |
| Latency 75th (ms)         | 0.29                |
| Latency 90th (ms)         | 0.34                |
| Latency 95th (ms)         | 0.37                |
| Latency 99th (ms)         | 0.45                |
| Mean latency (ms)         | 0.26                |
| Max latency (ms)          | 5.49                |
| Requests/sec              | 60,941              |
| Requests/sec (max)        | 69,579              |
| Read throughput (MB/s)    | 219.22              |