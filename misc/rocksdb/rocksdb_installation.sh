#!/bin/bash
## On Amazon Linux 2

# sudo su - root

## 安装工具链
yum -y groupinstall "Development Tools"
yum install -y gcc10 gcc10-c++ blas blas-devel openssl-devel snappy snappy-devel bzip2 bzip2-devel zlib zlib-devel lz4-devel dmidecode htop dstat

## 设置使用 GCC 10.x 版本
mv /usr/bin/gcc /usr/bin/gcc7.3
mv /usr/bin/g++ /usr/bin/g++7.3
mv /usr/bin/c++ /usr/bin/c++7.3
alternatives --install /usr/bin/gcc gcc /usr/bin/gcc10-cc  100
alternatives --install /usr/bin/g++ g++ /usr/bin/gcc10-c++ 100
alternatives --install /usr/bin/c++ c++ /usr/bin/gcc10-c++ 100
gcc --version
g++ --version
c++ --version

## 更新 cmake
cd /root/
ARCH=$(arch) 
VER=3.29.6
wget https://github.com/Kitware/CMake/releases/download/v${VER}/cmake-${VER}-linux-${ARCH}.sh
sh cmake-${VER}-linux-${ARCH}.sh --skip-license --prefix=/usr
cmake -version

## 编译 gflags-v2.2.2
cd /root/
yum remove -y gflags-devel
wget https://github.com/gflags/gflags/archive/refs/tags/v2.2.2.tar.gz
tar zxf v2.2.2.tar.gz && cd gflags-2.2.2
mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_CXX_FLAGS="-fPIC" ..
make && make install

## 编译 rocksdb
cd /root/
wget https://github.com/facebook/rocksdb/archive/refs/tags/v9.0.0.tar.gz
tar zxf v9.0.0.tar.gz && cd rocksdb-9.0.0
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DWITH_SNAPPY=ON -DWITH_LZ4=ON -DWITH_ZLIB=ON ..
make -j $(expr $(nproc) - 2)
make db_bench

## 简单验证
cd /root/rocksdb-9.0.0/build/
./db_bench --threads $(nproc) --benchmarks="fillseq,stats"
