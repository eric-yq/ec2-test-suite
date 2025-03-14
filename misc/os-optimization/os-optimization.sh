#############################################################################
## 这段可以用。
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

# 应用配置
sudo sysctl -p /etc/sysctl.d/99-network-performance.conf


##########################################################################################
#### 待验证
# 安装tuned工具
sudo yum install -y tuned

# 创建自定义tuned配置
sudo mkdir -p /etc/tuned/network-benchmark/
sudo tee /etc/tuned/network-benchmark/tuned.conf > /dev/null << 'EOF'
[main]
include=latency-performance

[cpu]
force_latency=1
governor=performance
energy_perf_bias=performance
min_perf_pct=100

[vm]
transparent_hugepages=never

[sysctl]
kernel.sched_min_granularity_ns=10000000
kernel.sched_wakeup_granularity_ns=15000000
kernel.sched_migration_cost_ns=5000000
EOF

# 启用自定义配置
sudo tuned-adm profile network-benchmark

# 禁用CPU节能特性
# echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor


#########################################################################################
#### 待验证
sudo tee /usr/local/bin/optimize-network.sh > /dev/null << 'EOF'
#!/bin/bash

# 获取主要网络接口
IFACE=$(ip route | grep default | awk '{print $5}')
echo "Optimizing network interface: $IFACE"

# 安装ethtool（如果尚未安装）
if ! command -v ethtool &> /dev/null; then
    yum install -y ethtool
fi

# 关闭网卡省电模式
ethtool -s $IFACE wol d

# 增加接收和发送队列大小
ethtool -G $IFACE rx 4096 tx 4096 || echo "Cannot modify queue size"

# 优化中断合并
ethtool -C $IFACE rx-usecs 50 rx-frames 64 tx-usecs 50 tx-frames 64 || echo "Cannot modify interrupt coalescing"

# 启用Jumbo帧（如果网络支持）
# ethtool -s $IFACE mtu 9000 || echo "Cannot set MTU to 9000"

# 优化网卡特性
ethtool -K $IFACE tso on gso on gro on lro off

# 显示当前配置
echo "Current network interface settings:"
ethtool -k $IFACE
ethtool -g $IFACE
ethtool -c $IFACE
EOF

sudo chmod +x /usr/local/bin/optimize-network.sh
# 创建系统服务使其开机自动运行
sudo tee /etc/systemd/system/network-optimize.service > /dev/null << 'EOF'
[Unit]
Description=Optimize Network Interface
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/optimize-network.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable network-optimize.service
sudo systemctl start network-optimize.service

###################################################################################
#### 待验证
sudo tee /usr/local/bin/setup-rps-rfs.sh > /dev/null << 'EOF'
#!/bin/bash

# 获取CPU核心数
NUM_CPUS=$(nproc)
ALL_CPUS_MASK=$(printf "%x" $((2**$NUM_CPUS-1)))

# 为基准测试预留一半CPU核心（前16个核心）
RPS_CPUS_MASK=$(printf "%x" $((2**16-1)))

# 设置RFS全局参数
echo 32768 > /proc/sys/net/core/rps_sock_flow_entries

# 为每个网络接口配置RPS/RFS
for IFACE in $(ls /sys/class/net/ | grep -v lo); do
  echo "Setting up RPS/RFS for $IFACE"
  
  # 获取接收队列数量
  NUM_RX_QUEUES=$(ls -d /sys/class/net/$IFACE/queues/rx-* | wc -l)
  
  # 为每个接收队列设置RPS和RFS
  for ((i=0; i<$NUM_RX_QUEUES; i++)); do
    echo $RPS_CPUS_MASK > /sys/class/net/$IFACE/queues/rx-$i/rps_cpus
    echo 4096 > /sys/class/net/$IFACE/queues/rx-$i/rps_flow_cnt
  done
  
  # 设置XPS（发送数据包处理）- 使用剩余的核心
  XPS_CPUS_MASK=$(printf "%x" $((2**$NUM_CPUS-1 - 2**16+1)))
  NUM_TX_QUEUES=$(ls -d /sys/class/net/$IFACE/queues/tx-* 2>/dev/null | wc -l)
  
  if [ $NUM_TX_QUEUES -gt 0 ]; then
    for ((i=0; i<$NUM_TX_QUEUES; i++)); do
      if [ -f /sys/class/net/$IFACE/queues/tx-$i/xps_cpus ]; then
        echo $XPS_CPUS_MASK > /sys/class/net/$IFACE/queues/tx-$i/xps_cpus
      fi
    done
  fi
done
EOF

sudo chmod +x /usr/local/bin/setup-rps-rfs.sh
# 创建系统服务
sudo tee /etc/systemd/system/rps-rfs-setup.service > /dev/null << 'EOF'
[Unit]
Description=Setup RPS and RFS for Network Optimization
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setup-rps-rfs.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable rps-rfs-setup.service
sudo systemctl start rps-rfs-setup.service

###################################################################################
#### 待验证
sudo tee /usr/local/bin/optimize-irq.sh > /dev/null << 'EOF'
#!/bin/bash

# 获取网络接口名称
IFACE=$(ip route | grep default | awk '{print $5}')

# 获取与网络接口相关的中断
IRQS=$(grep ${IFACE} /proc/interrupts | awk '{print $1}' | tr -d ':')

# 如果没有找到特定中断，则退出
if [ -z "$IRQS" ]; then
  echo "No IRQs found for $IFACE"
  exit 0
fi

# 为基准测试预留后16个核心（16-31）
# 将网络中断绑定到前16个核心（0-15）
IRQ_MASK=ffff  # 二进制表示0-15核心

# 设置中断亲和性
for IRQ in $IRQS; do
  echo "Setting IRQ $IRQ affinity to $IRQ_MASK"
  echo $IRQ_MASK > /proc/irq/$IRQ/smp_affinity
done

# 检查是否安装了irqbalance
if command -v irqbalance &> /dev/null; then
  # 配置irqbalance以尊重我们的设置
  sudo tee /etc/sysconfig/irqbalance > /dev/null << 'EOFIRQ'
IRQBALANCE_ONESHOT=0
# 禁止在CPU 16-31上处理中断
IRQBALANCE_BANNED_CPUS=ffff0000
EOFIRQ
  
  # 重启irqbalance服务
  sudo systemctl restart irqbalance
fi

# 显示当前中断分布
echo "Current IRQ distribution:"
cat /proc/interrupts | grep -E "CPU|$IFACE"
EOF

sudo chmod +x /usr/local/bin/optimize-irq.sh
# 创建系统服务
sudo tee /etc/systemd/system/irq-optimize.service > /dev/null << 'EOF'
[Unit]
Description=Optimize IRQ Affinity
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/optimize-irq.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable irq-optimize.service
sudo systemctl start irq-optimize.service

