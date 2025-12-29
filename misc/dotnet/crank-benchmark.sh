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
#### 结果: c6g.large
| application               |                     |
| ------------------------- | ------------------- |
| Max Process CPU Usage (%) | 90                  |
| Max Cores usage (%)       | 359                 |
| Max Working Set (MB)      | 200                 |
| Max Private Memory (MB)   | 349                 |
| Build Time (ms)           | 9,777               |
| Start Time (ms)           | 294                 |
| Published Size (KB)       | 107,947             |
| Symbols Size (KB)         | 23                  |
| .NET Core SDK Version     | 8.0.416             |
| ASP.NET Core Version      | 8.0.22+ee4174799332 |
| .NET Runtime Version      | 8.0.22+a2266c728f63 |
| Max Global CPU Usage (%)  | 100                 |


| load                      |                     |
| ------------------------- | ------------------- |
| Max Process CPU Usage (%) | 27                  |
| Max Cores usage (%)       | 108                 |
| Max Working Set (MB)      | 46                  |
| Max Private Memory (MB)   | 127                 |
| Build Time (ms)           | 7,371               |
| Start Time (ms)           | 94                  |
| Published Size (KB)       | 78,542              |
| Symbols Size (KB)         | 0                   |
| .NET Core SDK Version     | 8.0.416             |
| ASP.NET Core Version      | 8.0.22+ee4174799332 |
| .NET Runtime Version      | 8.0.22+a2266c728f63 |
| Max Global CPU Usage (%)  | 100                 |
| First Request (ms)        | 209                 |
| Requests                  | 630,266             |
| Bad responses             | 0                   |
| Latency 50th (ms)         | 5.44                |
| Latency 75th (ms)         | 6.95                |
| Latency 90th (ms)         | 9.16                |
| Latency 95th (ms)         | 12.07               |
| Latency 99th (ms)         | 20.04               |
| Mean latency (ms)         | 6.08                |
| Max latency (ms)          | 111.85              |
| Requests/sec              | 42,357              |
| Requests/sec (max)        | 60,341              |
| Read throughput (MB/s)    | 151.11              |

## 