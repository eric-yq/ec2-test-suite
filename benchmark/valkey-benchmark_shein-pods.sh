#!/bin/bash

#####################################################################
## 这个脚本是shein提供的测试命令，在一个EC2实例上启动多个pods时的测试。
## 使用方法： bash valkey-benchmark_shein-pods.sh <IP地址> <端口号>
#####################################################################

#####################################################################
# 网络优化配置
sudo tee /etc/sysctl.d/99-network-performance.conf > /dev/null << 'EOF'
# 网络队列和缓冲区优化
net.core.netdev_max_backlog = 250000
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.core.optmem_max = 16777216
net.core.somaxconn = 65535

# TCP优化
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_max_syn_backlog = 30000
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_window_scaling = 1

# 使用BBR拥塞控制算法（如果内核支持）
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# 增加本地端口范围
net.ipv4.ip_local_port_range = 1024 65535

# 软中断和网络处理优化
net.core.netdev_budget = 600
net.core.netdev_budget_usecs = 10000
net.core.dev_weight = 600

# 连接跟踪优化
net.netfilter.nf_conntrack_max = 2097152
net.netfilter.nf_conntrack_tcp_timeout_established = 86400
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30

# 禁用IPv6（如果不需要）
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

# 内存管理优化
vm.swappiness = 10
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.min_free_kbytes = 1048576
vm.zone_reclaim_mode = 0
vm.max_map_count = 1048576

# 文件系统和I/O优化
fs.file-max = 20000000
fs.nr_open = 20000000
fs.aio-max-nr = 1048576
fs.inotify.max_user_watches = 524288
EOF
sudo sysctl -p /etc/sysctl.d/99-network-performance.conf
##################################################################


SUT_IP_ADDR=${1}
PORT=${2}
DATASIZE=32
# OPTS="-t 2 -c 5 --pipeline=10"
OPTS="-t 2 -c 5 --pipeline=30"
# OPTS="-t 2 -c 5"


source /tmp/temp-setting
RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}_set_shein.txt"
memtier_benchmark $OPTS -s ${SUT_IP_ADDR} -p $PORT --distinct-client-seed --command="set __key__ __data__" --key-prefix="kv_" --key-minimum=1 --key-maximum=500 --random-data --data-size=$DATASIZE --test-time=180 --out-file=${RESULT_FILE} --hide-histogram 

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}_get_shein.txt"
memtier_benchmark $OPTS -s ${SUT_IP_ADDR} -p $PORT --distinct-client-seed --command="get __key__" --key-prefix="kv_" --key-minimum=1 --key-maximum=500 --test-time=180 --out-file=${RESULT_FILE} --hide-histogram 

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}_incr_shein.txt"
memtier_benchmark $OPTS -s ${SUT_IP_ADDR} -p $PORT --distinct-client-seed --command="incr __key__" --key-prefix="int_" --key-minimum=1 --key-maximum=500 --test-time=180 --out-file=${RESULT_FILE} --hide-histogram 

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}_lpush_shein.txt"
memtier_benchmark $OPTS -s ${SUT_IP_ADDR} -p $PORT --distinct-client-seed --command="lpush __key__ __data__" --key-prefix="list_" --key-minimum=1 --key-maximum=500 --random-data --data-size=$DATASIZE --test-time=180 --out-file=${RESULT_FILE} --hide-histogram 

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}_sadd_shein.txt"
memtier_benchmark $OPTS -s ${SUT_IP_ADDR} -p $PORT --distinct-client-seed --command="sadd __key__ __data__" --key-prefix="set_" --key-minimum=1 --key-maximum=500 --random-data --data-size=$DATASIZE --test-time=180 --out-file=${RESULT_FILE} --hide-histogram 

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}_zadd_shein.txt"
memtier_benchmark $OPTS -s ${SUT_IP_ADDR} -p $PORT --distinct-client-seed --command="zadd __key__ __key__ __data__" --key-prefix="" --key-minimum=1 --key-maximum=500 --random-data --data-size=$DATASIZE --test-time=180 --out-file=${RESULT_FILE} --hide-histogram 

RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${SUT_IP_ADDR}_${PORT}_hset_shein.txt"
memtier_benchmark $OPTS -s ${SUT_IP_ADDR} -p $PORT --distinct-client-seed --command="hset __key__ __data__ __data__" --key-prefix="hash_" --key-minimum=1 --key-maximum=500 --random-data --data-size=$DATASIZE --test-time=180 --out-file=${RESULT_FILE} --hide-histogram 
