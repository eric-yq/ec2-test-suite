#!/bin/bash
## On Amazon Linux 2

# sudo su - root


## 挂盘：
## 4xlarge 测试时仅使用 /dev/nvme1n1
## DB_DIR 和 WAL_DIR 都设置为 /data/nvme1n1
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


PRINT_INFO(){
    echo "[Info] $(date +%Y%m%d.%H%M%S) : $1"
}

## Benchmark 流程
PN=$(dmidecode -s system-product-name | tr ' ' '_')
LOG_PATH="$HOME/RocksDB_Benchmark_storage_workload_$PN"
mkdir -p $LOG_PATH

##################################################################################
## 磁盘工作负载
PRINT_INFO "Start to peform RocksDB In Storage Workload Performance Benchmarks"
cd /root/rocksdb-9.0.0/build
wget https://raw.githubusercontent.com/facebook/rocksdb/main/tools/benchmark.sh

export DB_DIR="/mnt/db/"
export WAL_DIR="/mnt/db/"
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


cp /root/nohup.out /tmp/benchmark_* /tmp/schedule.txt /tmp/report.tsv ${LOG_PATH}/
tar czfP ${LOG_PATH}.tar.gz ${LOG_PATH}