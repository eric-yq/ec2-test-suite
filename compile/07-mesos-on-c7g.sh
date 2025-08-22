#!/bin/bash

# r7g.2xlarge(Graviton3, 8C 64G), Rocky Linux 8.10, 40G gp3
# Rocky Linux 8.10 AMI ID 从 https://rockylinux.org/zh-CN/download 查找
# AMI 特殊说明：上面 URL 找到的 AMI 中通过 lvs 管理分区，需要提前将 rocky-root 扩展为 EBS 的大小。

sudo su - root

# 安装 JDK 和 Erlang
yum install -y -q epel-release
yum install -y -q erlang
# 查看版本
java -version
erl 

# 安装依赖包
yum groupinstall -y -q "Development Tools"
yum install -y -q tar wget git maven python2 python2-devel python2-six python2-virtualenv \
  java-1.8.0-openjdk-devel zlib-devel libcurl-devel openssl-devel cyrus-sasl-devel \
  cyrus-sasl-md5 apr-devel subversion-devel apr-util-devel

# 源码安装 mesos, 参考 https://mesos.apache.org/documentation/latest/building/
wget https://downloads.apache.org/mesos/1.11.0/mesos-1.11.0.tar.gz
tar -zxf mesos-1.11.0.tar.gz && cd mesos-1.11.0
./bootstrap
mkdir build && cd build
CXXFLAGS="-Wno-parentheses" ../configure
make  -j 4 V=0
make install

