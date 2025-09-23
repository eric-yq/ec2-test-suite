#!/bin/bash

## 先做镜像，在 HK region. 使用 root 用户登录

yum update -y

## 安装 apisix, redis, valkey 

##################################################################################################
## apisix
# 安装开发工具集
yum group install -y "Development Tools"
yum install -y gcc gcc-c++ make pcre pcre-devel zlib zlib-devel openssl openssl-devel gd gd-devel libxml2 libxml2-devel libxslt libxslt-devel geoip geoip-devel

# 安装 etcd
if [[ $(arch) == "x86_64" ]]; then
    ARCH="amd64"
else
    ARCH="arm64"
fi
cd ~
ETCD_VERSION='3.5.4'
wget https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-$ARCH.tar.gz
tar -xvf etcd-v${ETCD_VERSION}-linux-$ARCH.tar.gz && \
  cd etcd-v${ETCD_VERSION}-linux-$ARCH && \
  cp -a etcd etcdctl /usr/bin/
# nohup etcd >/tmp/etcd.log 2>&1 &
## 创建 systemd 服务文件：
cat << EOF > /etc/systemd/system/etcd.service
[Unit]
Description=etcd key-value store
Documentation=https://github.com/etcd-io/etcd
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


## 启用并启动服务：
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd
## 检查状态：
systemctl status etcd

## 安装 OpenResty 和 apisix, 使用 ecs-user 用户
cd ~
APISIX_VERSION='3.9.1'
# cd apisix-${APISIX_VERSION}
# sed -i.bak "s/LUAROCKS_VER=3.8.0/LUAROCKS_VER=3.12.0/g" utils/linux-install-luarocks.sh
# sed -i.bak "s/lualdap = 1.2.6-1/lualdap = 1.4.0/g" apisix-master-0.rockspec 
# sed -i.bak "s/sudo yum-config-manager/#sudo yum-config-manager/g" utils/install-dependencies.sh 
# utils/linux-install-luarocks.sh
# make deps -j && make install
yum install -y https://repos.apiseven.com/packages/centos/apache-apisix-repo-1.0-1.noarch.rpm
sed -i.bak "s/\$releasever/8/g" /etc/yum.repos.d/apache-apisix.repo
sed -i.bak "s/\$releasever/8/g" /etc/yum.repos.d/openresty.repo
yum clean all
yum makecache
yum install -y apisix-$APISIX_VERSION
# apisix init
# apisix start

# 安装 wrk
cd ~
wget https://github.com/wg/wrk/archive/refs/tags/4.2.0.tar.gz
tar zxf 4.2.0.tar.gz
cd wrk-4.2.0
make -j
ln -s ~/wrk-4.2.0/wrk /usr/bin/wrk
wrk -v

# benchmark
cd /opt         ## benchmark不能在/root 目录下执行。。。。
APISIX_VERSION='3.9.1'
git clone --depth 1 --branch ${APISIX_VERSION} https://github.com/apache/apisix.git apisix-${APISIX_VERSION}
cd apisix-${APISIX_VERSION}
sed -i.bak "s/LUAROCKS_VER=3.8.0/LUAROCKS_VER=3.12.0/g" utils/linux-install-luarocks.sh
sed -i.bak "s/lualdap = 1.2.6-1/lualdap = 1.4.0/g" apisix-master-0.rockspec 
bash utils/linux-install-luarocks.sh
sed -i.bak "s/sudo yum-config-manager/#sudo yum-config-manager/g" utils/install-dependencies.sh
make deps -j && make install
sed -i.bak "s/bash -x/bash/g"   ./benchmark/run.sh
sed -i "s/wrk -d 5/wrk -d 60/g" ./benchmark/run.sh

## run benchmark
ulimit -n 65535
rm -rf logs/* benchmark/fake-apisix/logs/*  && df -h
./benchmark/run.sh 1 && sleep 10
./benchmark/run.sh 2 && sleep 10
rm -rf logs/* benchmark/fake-apisix/logs/*  && df -h
./benchmark/run.sh 4 && sleep 10
./benchmark/run.sh 6 && sleep 10


##################################################################################################
## redis
cd /root
yum install -y python3-pip docker
pip3 install dool

# OS优化
# 禁用透明大页面（Transparent Huge Pages）
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
# 添加到 /etc/rc.local 以便在启动时生效
cat >> /etc/rc.local << EOF
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
  echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
  echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi
EOF
chmod +x /etc/rc.local
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
# 其他
cat >> /etc/security/limits.conf << EOF
# 如果使用 root 或其他用户运行
root soft nofile 1000000
root hard nofile 1000000
root soft nproc 65535
root hard nproc 65535
# 对所有用户设置
* soft nofile 1000000
* hard nofile 1000000
EOF
echo 1 > /proc/sys/vm/overcommit_memory

## 安装redis
docker pull redis:7.0.15
## 计算内存容量
MEM_TOTAL_GB=$(free -g |grep Mem | awk -F " " '{print $2}')
let XXX=${MEM_TOTAL_GB}*80/100
## 1. 配置一个单线程 redis, 不使用 io-threads
cat > /root/redis-6379.conf << EOF
port 6379
bind 0.0.0.0
protected-mode no
maxmemory ${XXX}gb
maxmemory-policy allkeys-lru
EOF

docker run -d --name redis-6379 --restart=always \
    -p 6379:6379 \
    -v /root/redis-6379.conf:/etc/redis/redis.conf \
    redis:7.0.15 \
    redis-server /etc/redis/redis.conf


##################################################################################################
## valkey
cd /root
docker pull valkey/valkey:8.1.0
## 配置 3 种 io-threads = 5
MEM_TOTAL_GB=$(free -g |grep Mem | awk -F " " '{print $2}')
let XXX=${MEM_TOTAL_GB}*80/100
let PORT=8005
cat > /root/valkey-$PORT.conf << EOF
bind 0.0.0.0
port 6379
protected-mode no
maxmemory ${XXX}gb
maxmemory-policy allkeys-lru
io-threads-do-reads yes
io-threads 5
EOF
# 启动 valkey
docker run -d --name valkey-$PORT --restart=always \
    -p $PORT:6379 \
    -v /root/valkey-$PORT.conf:/etc/valkey/valkey.conf \
    valkey/valkey:8.1.0 \
    valkey-server /etc/valkey/valkey.conf

sleep 3
docker ps -a 