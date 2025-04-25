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

# 生成配置文件，for cluster node
cat > /root/valkey.conf << EOF
port 6379
bind 0.0.0.0
protected-mode no
maxmemory ${XXX}gb
maxmemory-policy allkeys-lru
io-threads $YYY	
io-threads-do-reads yes
# for cluster
cluster-enabled yes
cluster-config-file cluster-nodes.conf
cluster-node-timeout 5000
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

##### valkey-benchmark sample
# 对于服务器为2xlarge, 可以测试[10,20,30,40,50]
docker exec -it valkey \
  valkey-benchmark -h $SERVER_IP_ADDR -n 10000000 -c 30
  
##### memtier_benchmark sample
THREAD_LIST="2 4 6 8 10 12 16"
for i in ${THREAD_LIST}
do
	redis-cli -h ${SUT_IP_ADDR} flushall
	RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}-${i}.txt"
	
	OPTS="-t ${i} -c 4"
	
	memtier_benchmark ${OPTS} -s ${SUT_IP_ADDR} --test-time ${TEST_TIME} \
	  --pipeline 10 --distinct-client-seed \
	  --key-pattern=R:R --key-prefix=TEST \
	  --random-data --data-size-range=1-4096 --data-size-pattern=S  \
	  −−randomize --hide-histogram --run-count=3 --ratio=1:5 \
	  --out-file=${RESULT_FILE}
done

