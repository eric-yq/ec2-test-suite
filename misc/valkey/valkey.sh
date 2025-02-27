#!/bin/bash

# amazon linux 2023

# 安装 Docker
yum install -yq docker htop python3-pip
pip3 install -q dool
systemctl enable docker
systemctl start docker

## 获取 CPU数 和 内存数量（KB）
CPU_CORES=$(nproc)
MEM_TOTAL_GB=$(free -g |grep Mem | awk -F " " '{print $2}')

## 变量计算
let XXX=${MEM_TOTAL_GB}*80/100
let YYY=${CPU_CORES}-2

# 生成配置文件
cat > /root/valkey.conf << EOF
port 6379
bind 0.0.0.0
protected-mode no
maxmemory ${XXX}gb
maxmemory-policy allkeys-lru
io-threads $YYY	
io-threads-do-reads yes
EOF

# 运行 Valkey 容器
docker run -d --name valkey \
  -p 6379:6379 \
  -v /root/valkey.conf:/etc/valkey/valkey.conf \
  valkey/valkey:7.2.8 \
  valkey-server /etc/valkey/valkey.conf

docker ps -a


##################################################################################### 
##### 客户端操作
SERVER_IP_ADDR=172.31.6.23
docker run -d --name valkey -p 6379:6379 valkey/valkey:latest
docker exec -it valkey valkey-cli -h $SERVER_IP_ADDR info

##### benchmark sample
# 对于服务器为2xlarge, 可以测试[10,20,30,40,50]
docker exec -it valkey \
  valkey-benchmark -h $SERVER_IP_ADDR -n 10000000 -c 30
