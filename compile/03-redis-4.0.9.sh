#!/bin/bash

## 实例名称： AB23-Demo-Redis4.0.9-编译-AL2
## 实例规格： r7g.2xlarge
## 编译时间： 3 分钟
## 在 /varlog/cloud-init-out.log 查看执行过程

cd /root/

## 安装开发工具、监控工具
yum update -y 
amazon-linux-extras install -y epel
yum groupinstall -y development
yum install -y gcc10 gcc10-c++
yum install -y dstat htop nload tcl

## 设置使用 GCC 10.4 版本
mv /usr/bin/gcc /usr/bin/gcc7.3
mv /usr/bin/g++ /usr/bin/g++7.3
alternatives --install /usr/bin/gcc gcc /usr/bin/gcc10-cc  100
alternatives --install /usr/bin/g++ g++ /usr/bin/gcc10-c++ 100
gcc --version
g++ --version

## Enable Transparent Huge Pages (THP) 
echo always > /sys/kernel/mm/transparent_hugepage/enabled

## 下载 Redis 指定版本源码
cd /root/
wget -q https://download.redis.io/releases/redis-4.0.9.tar.gz
tar zxf redis-4.0.9.tar.gz
cd /root/redis-4.0.9/

## 指定参数进行编译
make CFLAGS="-O3 -mcpu=neoverse-n1 -fsigned-char"

## 验证 Redis 功能
# make test

## 安装到 /usr/local/bin 目录
make install 

## 配置Redis
cp -f /root/redis-4.0.9/redis.conf /tmp/redis.conf
sed -i "s/bind 127.0.0.1/bind $(hostname -i)/g" /tmp/redis.conf
sed -i "s/daemonize no/daemonize yes/g" /tmp/redis.conf
sed -i "s/protected-mode yes/protected-mode no/g" /tmp/redis.conf

# 启动 Redis，每个 core 绑定一个 Redis 进程。
let REDIS_INSTANCE_NUMBER=$(nproc)-1

for i in `seq ${REDIS_INSTANCE_NUMBER}`
do
    ## PORT：redis-server 启动的端口号
    BASE=7000
    let PORT=${BASE}+${i}
    
    ## CORE_ID：redis-server 绑定到哪个 core 
    let CORE_ID=${i}-1
    
    ## 修改配置文件
    mkdir -p /root/redis-${PORT}/{data,logs,etc}
    cp /tmp/redis.conf /root/redis-${PORT}/etc/redis-${PORT}.conf
    sed -i "s/port 6379/port ${PORT}/g" /root/redis-${PORT}/etc/redis-${PORT}.conf
    sed -i "s/redis_6379.pid/redis_${PORT}.pid/g" /root/redis-${PORT}/etc/redis-${PORT}.conf
    sed -i "s/logfile \"\"/logfile \/root\/redis-${PORT}\/logs\/redis_${PORT}.log/g" /root/redis-${PORT}/etc/redis-${PORT}.conf
    sed -i "s/dir .\//dir \/root\/redis-${PORT}\/data\//g" /root/redis-${PORT}/etc/redis-${PORT}.conf
    sed -i "s/dbfilename dump.rdb/dbfilename dump-${PORT}.rdb/g" /root/redis-${PORT}/etc/redis-${PORT}.conf
    
    ## 启动 redis-server，绑定到指定的 core。
    nohup taskset -c ${CORE_ID} redis-server /root/redis-${PORT}/etc/redis-${PORT}.conf &
done
