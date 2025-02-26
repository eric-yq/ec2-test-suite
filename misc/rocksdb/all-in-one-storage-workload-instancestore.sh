#!/bin/bash
## On Amazon Linux 2

# sudo su - root

## 挂盘：
## 4xlarge 测试时仅使用 /dev/nvme1n1
## DB_DIR 和 WAL_DIR 都设置为 /data/nvme1n1p1
# disks="nvme1n1"
disks=$(lsblk |grep disk | grep -v nvme0 | grep -v xvda | sort | awk -F " " '{print $1}')
for disk in $disks
do
    echo "[INFO] Start to create partition on $disk..."
    echo -e "g\nn\n1\n\n\nw" | fdisk /dev/$disk

    echo "[INFO] Start to create filesystem on $device..."
    partition=${disk}p1 && mkdir -p /data/$partition
    device="/dev/$partition" && mkfs -t xfs -f $device

    echo "[INFO] Start to modify /etc/fstab..."
    uuid=$(blkid | grep $partition | awk -F "\"" '{print $2}')
    echo "UUID=$uuid /data/$partition xfs  defaults,discard  0  2" >> /etc/fstab
done
mount -a && df -h


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

PRINT_INFO(){
    echo "[Info] $(date +%Y%m%d.%H%M%S) : $1"
}

## Benchmark 流程
PN=$(dmidecode -s system-product-name | tr ' ' '_')
LOG_PATH="$HOME/RocksDB_Benchmark_storage_workload_instancestore_$PN"
mkdir -p $LOG_PATH

##################################################################################
## 磁盘工作负载
PRINT_INFO "Start to peform RocksDB In Storage Workload Performance Benchmarks"
cd /root/rocksdb-9.0.0/build
wget https://raw.githubusercontent.com/facebook/rocksdb/main/tools/benchmark.sh

export DB_DIR="/data/nvme1n1p1"
export WAL_DIR="/data/nvme1n1p1"

# 对于 r5d.4xlarge，带有 2*300G 的盘，这里将 WAL_DIR 放在另一块盘分担下容量压力。
# export WAL_DIR="/data/nvme2n1p1"
export COMPRESSION_TYPE=snappy 

ACTION="bulkload" && PRINT_INFO "  $ACTION....." && LOG_FILE="$LOG_PATH/$ACTION.log"
NUM_KEYS=900000000 CACHE_SIZE=6442450944 bash benchmark.sh bulkload > $LOG_FILE 2>&1

ACTION="readrandom" && PRINT_INFO "  $ACTION....." && LOG_FILE="$LOG_PATH/$ACTION.log"
NUM_KEYS=900000000 CACHE_SIZE=6442450944 DURATION=5400 bash benchmark.sh readrandom > $LOG_FILE 2>&1

ACTION="multireadrandom" && PRINT_INFO "  $ACTION....." && LOG_FILE="$LOG_PATH/$ACTION.log"
NUM_KEYS=900000000 CACHE_SIZE=6442450944 DURATION=5400 bash benchmark.sh multireadrandom --multiread_batched > $LOG_FILE 2>&1

ACTION="fwdrange" && PRINT_INFO "  $ACTION....." && LOG_FILE="$LOG_PATH/$ACTION.log"
NUM_KEYS=900000000 CACHE_SIZE=6442450944 DURATION=5400 bash benchmark.sh fwdrange > $LOG_FILE 2>&1

ACTION="revrange" && PRINT_INFO "  $ACTION....." && LOG_FILE="$LOG_PATH/$ACTION.log"
NUM_KEYS=900000000 CACHE_SIZE=6442450944 DURATION=5400 bash benchmark.sh revrange > $LOG_FILE 2>&1

ACTION="overwrite" && PRINT_INFO "  $ACTION....." && LOG_FILE="$LOG_PATH/$ACTION.log"
NUM_KEYS=900000000 CACHE_SIZE=6442450944 DURATION=5400 bash benchmark.sh overwrite > $LOG_FILE 2>&1

ACTION="readwhilewriting" && PRINT_INFO "  $ACTION....." && LOG_FILE="$LOG_PATH/$ACTION.log"
NUM_KEYS=900000000 CACHE_SIZE=6442450944 DURATION=5400 MB_WRITE_PER_SEC=2 bash benchmark.sh readwhilewriting

ACTION="fwdrangewhilewriting" && PRINT_INFO "  $ACTION....." && LOG_FILE="$LOG_PATH/$ACTION.log"
NUM_KEYS=900000000 CACHE_SIZE=6442450944 DURATION=5400 MB_WRITE_PER_SEC=2 bash benchmark.sh fwdrangewhilewriting > $LOG_FILE 2>&1

ACTION="revrangewhilewriting" && PRINT_INFO "  $ACTION....." && LOG_FILE="$LOG_PATH/$ACTION.log"
NUM_KEYS=900000000 CACHE_SIZE=6442450944 DURATION=5400 MB_WRITE_PER_SEC=2 bash benchmark.sh revrangewhilewriting > $LOG_FILE 2>&1

PRINT_INFO "Complete to peform RocksDB In Storage Workload Performance Benchmarks"

## 保存日志和结果文件
cp /root/nohup.out /tmp/benchmark_* /tmp/schedule.txt /tmp/report.tsv ${LOG_PATH}/
tar czfP ${LOG_PATH}.tar.gz ${LOG_PATH}

