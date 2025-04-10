#!/bin/bash

# amazon linux 2023

# 安装 Docker
yum install -yq docker htop python3-pip
pip3 install -q dool
systemctl enable docker
systemctl start docker

# 删除所有Exited 的容器
docker container prune

## 获取 CPU数 和 内存数量（KB）
CPU_CORES=$(nproc)
MEM_TOTAL_GB=$(free -g |grep Mem | awk -F " " '{print $2}')

## 变量计算
let XXX=${MEM_TOTAL_GB}*80/100
let YYY=4

# 生成配置文件
cat > /root/test.conf << EOF
port 6379
bind 0.0.0.0
protected-mode no
maxmemory ${XXX}gb
maxmemory-policy allkeys-lru
io-threads $YYY	
io-threads-do-reads yes
EOF

# 运行 Redis 容器
docker run -d --name redis-6379 \
  -p 6379:6379 \
  -v /root/test.conf:/etc/redis/redis.conf \
  redis:7.0.15 \
  redis-server /etc/redis/redis.conf

# 运行 Valkey 容器
docker run -d --name valkey-16379 \
  -p 16379:6379 \
  -v /root/test.conf:/etc/valkey/valkey.conf \
  valkey/valkey:8.1.0 \
  valkey-server /etc/valkey/valkey.conf

docker ps -a