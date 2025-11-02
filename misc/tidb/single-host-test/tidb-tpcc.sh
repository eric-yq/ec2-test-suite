#!/bin/bash

set -e

# 实例启动成功之后的首次启动 OS， /root/userdata.sh 不存在，创建该 userdata.sh 文件并设置开启自动执行该脚本。
if [ ! -f "/root/userdata.sh" ]; then
    echo "首次启动 OS, 未找到 /root/userdata.sh，准备创建..."
    # 复制文件
    cp /var/lib/cloud/instance/scripts/part-001 /root/userdata.sh
    chmod +x /root/userdata.sh
    # 创建 systemd 服务单元
    cat > /etc/systemd/system/userdata.service << EOF
[Unit]
Description=Execute userdata script at boot
After=network.target

[Service]
Type=oneshot
User=root
ExecStart=/root/userdata.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    # 启用服务
    systemctl daemon-reload
    systemctl enable userdata.service
    
    echo "已创建并启用 systemd 服务 userdata.service"

    ### 如果 3 分钟之后，实例没有重启，或者也有可能不需要重启，则开始启动服务执行后续安装过程。
    sleep 180
    systemctl start userdata.service
    systemctl disable userdata.service
    exit 0
fi

###################################################################################################
## 安装常用工具
yum update -yq
yum install -yq python3-pip htop
pip3 install dool

# 系统优化
cat > /etc/sysctl.d/tidb.conf << EOF
# 增加最大连接数
net.core.somaxconn = 32768
# 完全禁用交换
vm.swappiness = 0
# 增加脏页比例，减少刷盘频率
vm.dirty_ratio = 80
vm.dirty_background_ratio = 5
# 增加系统文件描述符限制
fs.file-max = 1000000
# 禁用syncookies以提高网络性能
net.ipv4.tcp_syncookies = 0
# 优化网络性能
net.core.netdev_max_backlog = 10000
net.ipv4.tcp_max_syn_backlog = 8096
EOF

sysctl -p /etc/sysctl.d/tidb.conf

# 禁用透明大页
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag

# 设置文件描述符限制
cat >> /etc/security/limits.conf << EOF
* soft nofile 1000000
* hard nofile 1000000
* soft stack 32768
* hard stack 32768
* soft core 2147483648
* hard core 2147483648
EOF

# 创建配置文件目录
mkdir -p ~/tidb-config
cd ~/tidb-config

# 创建上述三个配置文件
cat > tidb.toml << EOF
[log]
level = "error"

[performance]
# 分配4个CPU核心给TiDB
max-procs = 4
# 分配约30GB内存给TiDB
server-memory-quota = 32212254720
txn-total-size-limit = 1073741824
tcp-keep-alive = true

[prepared-plan-cache]
enabled = true
capacity = 10000

[tikv-client]
# 优化TiKV客户端连接
max-batch-size = 128
max-batch-wait-time = 2000000
grpc-connection-count = 8
commit-timeout = "41s"

[stmt-summary]
# 禁用语句摘要以减少开销
enable = false

[binlog]
# 禁用binlog
enable = false
EOF

cat > pd.toml << EOF
[log]
level = "error"

[replication]
# 使用单副本模式
max-replicas = 1
enable-placement-rules = true

[schedule]
# 调度优化
max-merge-region-keys = 0
max-merge-region-size = 0
max-pending-peer-count = 64
max-snapshot-count = 64
max-store-down-time = "30m"
leader-schedule-limit = 4
region-schedule-limit = 2048
replica-schedule-limit = 64
merge-schedule-limit = 8
EOF

cat > tikv.toml << EOF
[log]
level = "error"

[server]
# 增加gRPC并发度
grpc-concurrency = 8
# 优化gRPC连接
grpc-raft-conn-num = 2
# 启用内存预分配
end-point-enable-batch-if-possible = true

[storage]
# 禁用引擎日志以提高性能
enable-ttl = false
reserve-space = "0MB"

[storage.block-cache]
# 每个TiKV实例分配约45GB内存作为块缓存
# 两个TiKV实例共90GB
capacity = "45GB"

[readpool]
# 使用统一的线程池
storage.use-unified-pool = true
coprocessor.use-unified-pool = true

[readpool.unified]
# 优化读取线程池
min-thread-count = 4
max-thread-count = 12
max-tasks-per-worker = 2000

[raftstore]
# 优化Raft存储
apply-max-batch-size = 1024
store-max-batch-size = 1024
apply-pool-size = 3
store-pool-size = 3
# 关闭不必要的Raft日志GC以提高性能
raft-log-gc-threshold = 100000
raft-log-gc-count-limit = 100000
raft-log-gc-tick-interval = "10s"
# 优化Raft心跳
raft-base-tick-interval = "1s"
raft-heartbeat-ticks = 2
raft-election-timeout-ticks = 10
# 关闭区域休眠功能
hibernate-regions = false

[rocksdb]
# 优化RocksDB配置
max-background-jobs = 8
max-sub-compactions = 3
max-open-files = 10000

# 优化默认列族
[rocksdb.defaultcf]
block-size = "64KB"
compression-per-level = ["no", "no", "lz4", "lz4", "lz4", "zstd", "zstd"]
write-buffer-size = "256MB"
max-write-buffer-number = 5
min-write-buffer-number-to-merge = 1
max-bytes-for-level-base = "1GB"
target-file-size-base = "64MB"
level0-file-num-compaction-trigger = 4
level0-slowdown-writes-trigger = 20
level0-stop-writes-trigger = 36
bloom-filter-bits-per-key = 10
block-cache-size = "18GB"
disable-auto-compactions = false

# 优化写列族
[rocksdb.writecf]
block-size = "64KB"
compression-per-level = ["no", "no", "lz4", "lz4", "lz4", "zstd", "zstd"]
write-buffer-size = "256MB"
max-write-buffer-number = 5
min-write-buffer-number-to-merge = 1
max-bytes-for-level-base = "1GB"
target-file-size-base = "64MB"
level0-file-num-compaction-trigger = 4
level0-slowdown-writes-trigger = 20
level0-stop-writes-trigger = 36
block-cache-size = "18GB"
disable-auto-compactions = false

# 优化锁列族
[rocksdb.lockcf]
block-size = "16KB"
compression-per-level = ["no", "no", "no", "no", "no", "no", "no"]
write-buffer-size = "128MB"
max-write-buffer-number = 5
min-write-buffer-number-to-merge = 1
max-bytes-for-level-base = "256MB"
target-file-size-base = "32MB"
level0-file-num-compaction-trigger = 1
level0-slowdown-writes-trigger = 16
level0-stop-writes-trigger = 24
block-cache-size = "9GB"
disable-auto-compactions = false

# 优化Raft DB
[raftdb]
max-background-jobs = 4
max-sub-compactions = 2

[raftdb.defaultcf]
compression-per-level = ["no", "no", "lz4", "lz4", "lz4", "zstd", "zstd"]
write-buffer-size = "128MB"
max-write-buffer-number = 5
max-bytes-for-level-base = "512MB"
target-file-size-base = "32MB"
block-cache-size = "2GB"

# 关闭备份功能以提高性能
[backup]
num-threads = 1
EOF

# 安装 TiUP
cd /root/
curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh
source /root/.bash_profile
tiup install playground
tiup install bench

# 更新 TiUP 自身
# tiup update --self
# tiup mirror set https://tiup-mirrors.pingcap.com
# tiup mirror refresh

# 启动集群
tiup playground v8.1.2 \
  --db 1 \
  --pd 1 \
  --kv 2 \
  --db.config ~/tidb-config/tidb.toml \
  --pd.config ~/tidb-config/pd.toml \
  --kv.config ~/tidb-config/tikv.toml \
  --host 0.0.0.0 \
  --without-monitor

echo "[Info] 等待(5 分钟) TiDB 集群启动完成......" && sleep 300

## 准备进行 TPCC 测试
SUT_NAME="tidb-tpcc"
WARES=5000
IPADDR=$(ec2-metadata --quiet --local-ipv4)
INSTANCE_TYPE=$(ec2-metadata --quiet --instance-type)
RESULT_PATH="/root/tidb-tpcc-results-${INSTANCE_TYPE}-${WARES}-warehouses"
mkdir -p ${RESULT_PATH}
PREPARE_RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_prepare_${WARES}_warehouses.txt"
CHECK_RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_check_${WARES}_warehouses.txt"
RUN_RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_run_${WARES}_warehouses.txt"

## 启动一个后台进程，执行dool命令，获取系统性能信息
DOOL_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${IPADDR}_dool.txt"
dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60 720 1> ${DOOL_FILE} 2>&1 &

# 准备 tpcc 数据：根据数据量，时间比较长, 每个 warehouse 约 100 MB 数据
tiup bench tpcc -H ${IPADDR} -P 4000 -D tpcc --warehouses ${WARES} --threads $(nproc) prepare > ${PREPARE_RESULT_FILE} 2>&1
echo "[Info] TPCC 数据准备完成！" && sleep 10

# tiup bench tpcc -H ${IPADDR} -P 4000 -D tpcc --warehouses ${WARES} check > ${CHECK_RESULT_FILE} 2>&1
# echo "[Info] TPCC 数据校验完成！" && sleep 10

## 执行 TPCC 测试
i=8
tiup bench tpcc -H ${IPADDR} -P 4000 -D tpcc --warehouses ${WARES} --threads ${i} --time 1h run > ${RUN_RESULT_FILE} 2>&1
echo "[Info] TPCC 测试完成！"

# 清理测试数据
tiup bench tpcc -H ${IPADDR} -P 4000 -D tpcc --warehouses ${WARES} cleanup

systemctl disable userdata.service
killall dool

## 数据量统计，当前tidb/tikv 配置下：
# 1000 warehouses 约 100 GB 磁盘容量: 线程数 8 , 1 小时测试结果：
## r8g.4xlarge 实例：CPU 利用率 60% 左右（usr+sys+wait）
# [Summary] DELIVERY - Takes(s): 3599.9, Count: 106778, TPM: 1779.7, Sum(ms): 3299171.4, Avg(ms): 30.9, 50th(ms): 30.4, 90th(ms): 35.7, 95th(ms): 37.7, 99th(ms): 41.9, 99.9th(ms): 50.3, Max(ms): 109.1
# [Summary] DELIVERY_ERR - Takes(s): 3599.9, Count: 1, TPM: 0.0, Sum(ms): 11.3, Avg(ms): 11.3, 50th(ms): 11.5, 90th(ms): 11.5, 95th(ms): 11.5, 99th(ms): 11.5, 99.9th(ms): 11.5, Max(ms): 11.5
# [Summary] NEW_ORDER - Takes(s): 3600.0, Count: 1205958, TPM: 20099.5, Sum(ms): 13975260.0, Avg(ms): 11.6, 50th(ms): 11.5, 90th(ms): 14.2, 95th(ms): 15.2, 99th(ms): 17.8, 99.9th(ms): 24.1, Max(ms): 121.6
# [Summary] NEW_ORDER_ERR - Takes(s): 3600.0, Count: 1, TPM: 0.0, Sum(ms): 3.9, Avg(ms): 3.9, 50th(ms): 4.2, 90th(ms): 4.2, 95th(ms): 4.2, 99th(ms): 4.2, 99.9th(ms): 4.2, Max(ms): 4.2
# [Summary] ORDER_STATUS - Takes(s): 3599.9, Count: 107279, TPM: 1788.0, Sum(ms): 876233.6, Avg(ms): 8.2, 50th(ms): 7.3, 90th(ms): 15.7, 95th(ms): 17.8, 99th(ms): 21.0, 99.9th(ms): 26.2, Max(ms): 117.4
# [Summary] PAYMENT - Takes(s): 3600.0, Count: 1152257, TPM: 19204.4, Sum(ms): 9490873.2, Avg(ms): 8.2, 50th(ms): 8.4, 90th(ms): 10.5, 95th(ms): 11.0, 99th(ms): 12.6, 99.9th(ms): 19.9, Max(ms): 436.2
# [Summary] PAYMENT_ERR - Takes(s): 3600.0, Count: 2, TPM: 0.0, Sum(ms): 1.3, Avg(ms): 0.8, 50th(ms): 1.0, 90th(ms): 1.0, 95th(ms): 1.0, 99th(ms): 1.0, 99.9th(ms): 1.0, Max(ms): 1.0
# [Summary] STOCK_LEVEL - Takes(s): 3599.9, Count: 107300, TPM: 1788.4, Sum(ms): 770250.0, Avg(ms): 7.2, 50th(ms): 6.3, 90th(ms): 9.4, 95th(ms): 12.6, 99th(ms): 32.5, 99.9th(ms): 60.8, Max(ms): 117.4

## r6i.4xlarge 实例：CPU 利用率 60% 左右（usr+sys+wait）
# [Summary] DELIVERY - Takes(s): 3599.9, Count: 91739, TPM: 1529.0, Sum(ms): 3356105.2, Avg(ms): 36.6, 50th(ms): 37.7, 90th(ms): 41.9, 95th(ms): 44.0, 99th(ms): 50.3, 99.9th(ms): 58.7, Max(ms): 88.1
# [Summary] NEW_ORDER - Takes(s): 3600.0, Count: 1029421, TPM: 17157.2, Sum(ms): 13997003.0, Avg(ms): 13.6, 50th(ms): 13.6, 90th(ms): 16.3, 95th(ms): 17.8, 99th(ms): 21.0, 99.9th(ms): 27.3, Max(ms): 121.6
# [Summary] NEW_ORDER_ERR - Takes(s): 3600.0, Count: 1, TPM: 0.0, Sum(ms): 7.3, Avg(ms): 7.1, 50th(ms): 7.3, 90th(ms): 7.3, 95th(ms): 7.3, 99th(ms): 7.3, 99.9th(ms): 7.3, Max(ms): 7.3
# [Summary] ORDER_STATUS - Takes(s): 3599.9, Count: 91485, TPM: 1524.8, Sum(ms): 890627.3, Avg(ms): 9.7, 50th(ms): 9.4, 90th(ms): 17.8, 95th(ms): 19.9, 99th(ms): 23.1, 99.9th(ms): 26.2, Max(ms): 159.4
# [Summary] PAYMENT - Takes(s): 3600.0, Count: 983882, TPM: 16398.2, Sum(ms): 9276517.8, Avg(ms): 9.4, 50th(ms): 9.4, 90th(ms): 11.5, 95th(ms): 12.1, 99th(ms): 13.6, 99.9th(ms): 21.0, Max(ms): 79.7
# [Summary] PAYMENT_ERR - Takes(s): 3600.0, Count: 2, TPM: 0.0, Sum(ms): 19.3, Avg(ms): 9.7, 50th(ms): 10.0, 90th(ms): 10.0, 95th(ms): 10.0, 99th(ms): 10.0, 99.9th(ms): 10.0, Max(ms): 10.0
# [Summary] STOCK_LEVEL - Takes(s): 3599.8, Count: 90670, TPM: 1511.3, Sum(ms): 874669.1, Avg(ms): 9.6, 50th(ms): 8.4, 90th(ms): 12.6, 95th(ms): 19.9, 99th(ms): 50.3, 99.9th(ms): 83.9, Max(ms): 151.0
# [Summary] STOCK_LEVEL_ERR - Takes(s): 3599.8, Count: 1, TPM: 0.0, Sum(ms): 10.0, Avg(ms): 10.2, 50th(ms): 10.5, 90th(ms): 10.5, 95th(ms): 10.5, 99th(ms): 10.5, 99.9th(ms): 10.5, Max(ms): 10.5


# 1000 warehouses 约 100 GB 磁盘容量: 线程数 8 , 1 小时测试结果：
## r8g.4xlarge 实例：CPU 利用率 65% 左右（usr+sys+wait）

## r6i.4xlarge 实例：CPU 利用率 60% 左右（usr+sys+wait）