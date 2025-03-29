#!/bin/bash

echo "[Info] Perform some OS optimization..."

##############################################################################
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
net.ipv4.tcp_max_syn_backlog = 65535
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
# net.netfilter.nf_conntrack_max = 2097152
# net.netfilter.nf_conntrack_tcp_timeout_established = 86400
# net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30

# 禁用IPv6（如果不需要）
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

# 内存管理优化
vm.swappiness = 0
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

ulimit -n 1000000

cat >> /etc/security/limits.conf << EOF
# 如果使用 root 或其他用户运行，也需要设置
root soft nofile 1000000
root hard nofile 1000000
root soft nproc 65535
root hard nproc 65535

# 对所有用户设置
* soft nofile 1000000
* hard nofile 1000000
EOF

##############################################################################
# 中断亲和性设置 ，绑定在指定CPU上。   
systemctl stop irqbalance
IFACE=$(ip route | grep default | awk '{print $5}')
irqs=$(grep "${IFACE}-Tx-Rx" /proc/interrupts | awk -F':' '{print $1}')
cpu=0
for i in $irqs; do
  echo $cpu > /proc/irq/$i/smp_affinity_list
  let cpu=${cpu}+1
done

##############################################################################
# 其他配置
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo 1 > /proc/sys/vm/overcommit_memory
