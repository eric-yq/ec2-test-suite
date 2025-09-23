#!/bin/bash

## 安装 memtier_benchmark, wrk, HammerDB 等工具

sudo su - root
yum update -y

# 安装开发工具集
yum -yq groupinstall "Development Tools"
yum -yq install java-11-alibaba-dragonwell pcre-devel zlib-devel libmemcached-devel libevent-devel \
                openssl-devel libaio-devel mariadb-devel cmake maven git redis screen htop

## memtier_benchmark
cd /root/ && \
git clone https://github.com/RedisLabs/memtier_benchmark.git && \
cd memtier_benchmark && \
git checkout tags/2.0.0 && \
autoreconf -ivf && \
./configure && \
make -j && \
sudo make install && \
memtier_benchmark --version && \
echo "memtier_benchmark installation complete!"

## wrk
echo "Installing wrk-4.2.0 for nginx/apisix benchmark ..."
cd /root/ && \
wget https://github.com/wg/wrk/archive/refs/tags/4.2.0.tar.gz && \
tar zxf 4.2.0.tar.gz && rm -rf 4.2.0.tar.gz && \
cd wrk-4.2.0 && \
make -j && \
echo "wrk installation complete!"

## HammerDB
cd /root/ && \
wget https://github.com/TPC-Council/HammerDB/releases/download/v4.4/HammerDB-4.4-Linux.tar.gz && \
tar zxf HammerDB-4.4-Linux.tar.gz && \
rm -rf HammerDB-4.4-Linux.tar.gz && \
echo "HammerDB installation complete!"

## YCSB
echo "Installing YCSB-0.17.0 for MongoDB benchmark ..."
cd /root/ && \
wget https://github.com/brianfrankcooper/YCSB/releases/download/0.17.0/ycsb-0.17.0.tar.gz && \
tar zxf ycsb-0.17.0.tar.gz && rm -rf ycsb-0.17.0.tar.gz && \
echo "YCSB installation complete!"

