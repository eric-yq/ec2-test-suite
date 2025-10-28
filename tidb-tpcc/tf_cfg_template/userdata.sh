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

# OS系统优化
# 增加系统文件描述符限制
sudo sh -c 'echo "* soft nofile 1000000" >> /etc/security/limits.conf'
sudo sh -c 'echo "* hard nofile 1000000" >> /etc/security/limits.conf'

# 调整内核参数
sudo sysctl -w fs.file-max=1000000
sudo sysctl -w net.core.somaxconn=65535  # 增加到最大值
sudo sysctl -w vm.swappiness=0  # 禁用交换
sudo sysctl -w vm.dirty_ratio=50  # 增加脏页比例
sudo sysctl -w vm.dirty_background_ratio=20
sudo sysctl -w vm.overcommit_memory=1  # 允许内存过量使用

# 增加共享内存限制
sudo sysctl -w kernel.shmmax=68719476736  # 64GB
sudo sysctl -w kernel.shmall=4294967296

# 优化网络缓冲区
sudo sysctl -w net.core.rmem_max=16777216
sudo sysctl -w net.core.wmem_max=16777216
sudo sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
sudo sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"

## 准备 TiDB 各个组件的配置文件
cd /root/
mkdir -p conf
cat << EOF > conf/tidb.toml
# 性能相关配置
performance.max-procs = 4
performance.server-memory-quota = 6442450944  # 每个实例约6GB
performance.txn-total-size-limit = 2147483648  # 增加事务大小限制到2GB
performance.max-txn-ttl = 3600000
performance.stats-lease = "3s"

# 启用执行计划缓存
prepared-plan-cache.enabled = true
prepared-plan-cache.capacity = 1000  # 增加缓存容量

# 内存表配置
mem-table-size = 34359738368  # 32GB，所有TiDB实例共享

# 优化客户端连接到TiKV的配置
tikv-client.max-batch-wait-time = 2000000  # 2ms
tikv-client.max-batch-size = 128
tikv-client.grpc-connection-count = 8
tikv-client.commit-timeout = "41s"  # 增加提交超时

# 优化日志以减少IO开销
log.level = "error"

# SQL优化器配置
[sql-optimizer]
tidb_multi_statement_mode = "ON"
tidb_opt_insubq_to_join_and_agg = true
tidb_opt_correlation_threshold = 0.9
tidb_opt_correlation_exp_factor = 1

# 执行器配置
[execution]
dist-sql.scan-concurrency = 15  # 增加扫描并发度
EOF

cat << EOF > conf/tikv.toml
[server]
# 增加并发处理能力
grpc-concurrency = 6
# 增加接收和发送消息的缓冲区大小
end-point-max-concurrency = 24

[readpool.storage]
# 存储读取线程池配置
normal-concurrency = 10
high-concurrency = 20

[readpool.coprocessor]
# 协处理器线程池配置
normal-concurrency = 10
high-concurrency = 20

[storage]
# 调度器工作线程池大小
scheduler-worker-pool-size = 8
# 启用异步提交以减少写入延迟
enable-async-commit = true
enable-1pc = true

[rocksdb]
# 增加后台作业数量以加速压缩
max-background-jobs = 8
max-sub-compactions = 4

# 默认列族 - 存储实际用户数据
[rocksdb.defaultcf]
# 大幅增加块缓存大小
block-cache-size = "20GB"
# 优化写缓冲区
write-buffer-size = "256MB"
max-write-buffer-number = 6
min-write-buffer-number-to-merge = 2
# 调整压缩
compression-per-level = ["no", "no", "lz4", "lz4", "lz4", "zstd", "zstd"]
# 增加L0-L1层的大小限制
max-bytes-for-level-base = "1GB"
target-file-size-base = "128MB"
# 增加L0文件数阈值，减少写停顿
level0-slowdown-writes-trigger = 30
level0-stop-writes-trigger = 40

# 写列族 - 存储MVCC信息和索引
[rocksdb.writecf]
# 增加块缓存
block-cache-size = "12GB"
write-buffer-size = "256MB"
max-write-buffer-number = 6
min-write-buffer-number-to-merge = 2
# 写CF的压缩设置
compression-per-level = ["no", "no", "lz4", "lz4", "zstd", "zstd", "zstd"]
# 调整文件大小限制
max-bytes-for-level-base = "1GB"
target-file-size-base = "128MB"

# 锁列族 - 存储锁信息
[rocksdb.lockcf]
# 适度增加块缓存
block-cache-size = "4GB"
# 锁CF的写缓冲区
write-buffer-size = "128MB"
max-write-buffer-number = 4
# 锁CF通常较小，使用较轻的压缩
compression-per-level = ["no", "no", "no", "lz4", "lz4", "zstd", "zstd"]

# Raft引擎配置
[raftdb]
max-background-jobs = 4
max-sub-compactions = 2

# Raft存储配置
[raftstore]
# 增加应用池和存储池大小
apply-pool-size = 4
store-pool-size = 4
# 增加Raft消息大小限制
raft-max-size-per-msg = "32MB"
raft-entry-max-size = "32MB"
# 增加区域大小限制，减少分裂次数
region-max-size = "384MB"
region-split-size = "256MB"
# 调整Raft基础超时
raft-base-tick-interval = "1s"
raft-election-timeout-ticks = 10
# 启用批处理以提高写入性能
apply-batch-system.max-batch-size = 256

# 提升Coprocessor性能
[coprocessor]
split-region-on-table = true
batch-split-limit = 10
EOF

cat << EOF > conf/pd.toml
# 调度器配置
[schedule]
# 禁用自动合并小区域，减少调度开销
max-merge-region-size = 0
max-merge-region-keys = 0
split-merge-interval = "1h"
# 增加调度并发度
max-snapshot-count = 10
max-pending-peer-count = 64
# 启用跨表合并
enable-cross-table-merge = true
# 增加调度器限制
leader-schedule-limit = 8
region-schedule-limit = 2048
replica-schedule-limit = 64
# 优化热点区域调度
hot-region-schedule-limit = 8
hot-region-cache-hits-threshold = 8

# 调整PD的内存使用
[quota]
# 增加region-cache大小
region-cache-ttl = 600

# 优化etcd配置
[etcd]
# 增加最大请求大小
max-request-bytes = 10485760  # 10MB
EOF

# 安装 TiUP 和 TiDB 集群
cd /root/
curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh
source /root/.bash_profile
IPADDR=$(ec2-metadata --quiet --local-ipv4)
nohup tiup playground --host ${IPADDR} \
  --db 1 \
  --kv 3 \
  --pd 1 \
  --db.config conf/tidb.toml \
  --kv.config conf/tikv.toml \
  --pd.config conf/pd.toml &

echo "[Info] 等待(3 分钟) TiDB 集群启动完成......" && sleep 180

## 准备进行 TPCC 测试
tiup install bench
SUT_NAME="tidb-tpcc"
WARES=100
IPADDR=$(ec2-metadata --quiet --local-ipv4)
INSTANCE_TYPE=$(ec2-metadata --quiet --instance-type)
RESULT_PATH="/root/tidb-tpcc-results-${INSTANCE_TYPE}-${WARES}-warehouses"
mkdir -p ${RESULT_PATH}
PREPARE_RESULT_FILE="${RESULT_PATH}/tidb-tpcc_prepare_${WARES}_warehouses.txt"
CHECK_RESULT_FILE="${RESULT_PATH}/tidb-tpcc_check_${WARES}_warehouses.txt"
RUN_RESULT_FILE="${RESULT_PATH}/tidb-tpcc_run_${WARES}_warehouses.txt"

## 启动一个后台进程，执行dool命令，获取系统性能信息
DOOL_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${IPADDR}_dool.txt"
dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60 720 1> ${DOOL_FILE} 2>&1 &

# 准备 tpcc 数据：根据数据量，时间比较长, 每个 warehouse 约 100 MB 数据
tiup bench tpcc -H ${IPADDR} -P 4000 -D tpcc --warehouses ${WARES} --threads $(nproc) prepare > ${PREPARE_RESULT_FILE} 2>&1
echo "[Info] TPCC 数据准备完成！" && sleep 10

# tiup bench tpcc -H ${IPADDR} -P 4000 -D tpcc --warehouses ${WARES} check > ${CHECK_RESULT_FILE} 2>&1
# echo "[Info] TPCC 数据校验完成！" && sleep 10

## 执行 TPCC 测试
tiup bench tpcc -H ${IPADDR} -P 4000 -D tpcc --warehouses ${WARES} --threads $(nproc) --time 3h run > ${RUN_RESULT_FILE} 2>&1
echo "[Info] TPCC 测试完成！"

systemctl disable userdata.service
killall dool