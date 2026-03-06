# 节点规划
# Node 1 (IP: N1):  mongos + config server + shard1-primary + shard2-secondary
# Node 2 (IP: N2):  mongos + config server + shard1-secondary + shard2-primary
# Node 3 (IP: N3):  mongos + config server + shard1-secondary + shard2-secondary

# 组件	端口
# mongos	27017
# config server	27019
# shard1	27018
# shard2	27020
# 以下步骤中 N1、N2、N3 替换为实际私有 IP。

# Phase 1: 基础环境准备（3 台机器都执行）
# Step 1: 安装 MongoDB 8.0
sudo apt-get install -y gnupg curl

curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
  sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor

echo "deb [ arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" | \
  sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list

sudo apt-get update
sudo apt-get install -y mongodb-org

# 停止默认 mongod 服务
sudo systemctl stop mongod
sudo systemctl disable mongod

# 验证
mongod --version

# Step 2: 创建目录
sudo mkdir -p /data/configdb
sudo mkdir -p /data/shard1
sudo mkdir -p /data/shard2
sudo mkdir -p /var/log/mongodb
sudo mkdir -p /var/run/mongodb

sudo chown -R mongodb:mongodb /data /var/log/mongodb /var/run/mongodb

# # Step 3: 生成 keyfile（仅 Node 1 执行，后续启用认证时使用）
# # Node 1 上生成
# sudo openssl rand -base64 756 > /tmp/mongodb-keyfile
# sudo cp /tmp/mongodb-keyfile /etc/mongodb-keyfile
# sudo chmod 400 /etc/mongodb-keyfile
# sudo chown mongodb:mongodb /etc/mongodb-keyfile

# # 复制到 Node 2 和 Node 3
# scp /tmp/mongodb-keyfile N2:/tmp/
# scp /tmp/mongodb-keyfile N3:/tmp/

# # Node 2 和 Node 3 上执行
# sudo cp /tmp/mongodb-keyfile /etc/mongodb-keyfile
# sudo chmod 400 /etc/mongodb-keyfile
# sudo chown mongodb:mongodb /etc/mongodb-keyfile

# Phase 2: 配置文件（3 台机器都创建）
# Step 4: Config Server 配置
# 创建 /etc/mongod-configsvr.conf
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/configsvr.log

storage:
  dbPath: /data/configdb

processManagement:
  fork: true
  pidFilePath: /var/run/mongodb/configsvr.pid

net:
  port: 27019
  bindIp: 0.0.0.0

replication:
  replSetName: configRS

sharding:
  clusterRole: configsvr

# Step 5: Shard 1 配置
# 创建 /etc/mongod-shard1.conf
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/shard1.log

storage:
  dbPath: /data/shard1
  wiredTiger:
    engineConfig:
      cacheSizeGB: 20

processManagement:
  fork: true
  pidFilePath: /var/run/mongodb/shard1.pid

net:
  port: 27018
  bindIp: 0.0.0.0

replication:
  replSetName: shard1RS

sharding:
  clusterRole: shardsvr

# Step 6: Shard 2 配置
# 创建 /etc/mongod-shard2.conf
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/shard2.log

storage:
  dbPath: /data/shard2
  wiredTiger:
    engineConfig:
      cacheSizeGB: 20

processManagement:
  fork: true
  pidFilePath: /var/run/mongodb/shard2.pid

net:
  port: 27020
  bindIp: 0.0.0.0

replication:
  replSetName: shard2RS

sharding:
  clusterRole: shardsvr

# Step 7: mongos 配置
# 创建 /etc/mongos.conf
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongos.log

processManagement:
  fork: true
  pidFilePath: /var/run/mongodb/mongos.pid

net:
  port: 27017
  bindIp: 0.0.0.0

sharding:
  configDB: configRS/N1:27019,N2:27019,N3:27019

# Phase 3: 启动 Config Server
# Step 8: 启动 Config Server（3 台机器都执行）
sudo -u mongodb mongod --config /etc/mongod-configsvr.conf

# 验证：
ps aux | grep configsvr
ss -tlnp | grep 27019

# Step 9: 初始化 Config Server Replica Set（仅 Node 1 执行）
mongosh --host 127.0.0.1 --port 27019
rs.initiate({
  _id: "configRS",
  configsvr: true,
  members: [
    { _id: 0, host: "N1:27019" },
    { _id: 1, host: "N2:27019" },
    { _id: 2, host: "N3:27019" }
  ]
})

// 等待几秒后验证
rs.status()

# 确认输出中有一个 PRIMARY 和两个 SECONDARY 后继续。

# Phase 4: 启动 Shard 1
# Step 10: 启动 Shard 1（3 台机器都执行）
sudo -u mongodb mongod --config /etc/mongod-shard1.conf

# 验证：
ss -tlnp | grep 27018

# Step 11: 初始化 Shard 1 Replica Set（仅 Node 1 执行）
mongosh --host 127.0.0.1 --port 27018
rs.initiate({
  _id: "shard1RS",
  members: [
    { _id: 0, host: "N1:27018", priority: 2 },
    { _id: 1, host: "N2:27018", priority: 1 },
    { _id: 2, host: "N3:27018", priority: 1 }
  ]
})

// 等待几秒后验证
rs.status()

# Phase 5: 启动 Shard 2
# Step 12: 启动 Shard 2（3 台机器都执行）
sudo -u mongodb mongod --config /etc/mongod-shard2.conf

# 验证：
ss -tlnp | grep 27020

# Step 13: 初始化 Shard 2 Replica Set（仅 Node 2 执行）
mongosh --host 127.0.0.1 --port 27020
rs.initiate({
  _id: "shard2RS",
  members: [
    { _id: 0, host: "N1:27020", priority: 1 },
    { _id: 1, host: "N2:27020", priority: 2 },
    { _id: 2, host: "N3:27020", priority: 1 }
  ]
})

// 等待几秒后验证
rs.status()

# Phase 6: 启动 mongos 并组建集群
# Step 14: 启动 mongos（3 台机器都执行）
sudo -u mongodb mongos --config /etc/mongos.conf

# 验证：
ss -tlnp | grep 27017

# Step 15: 添加 Shard 到集群（仅 Node 1 执行）
mongosh --host 127.0.0.1 --port 27017
// 添加两个 shard
sh.addShard("shard1RS/N1:27018,N2:27018,N3:27018")
sh.addShard("shard2RS/N1:27020,N2:27020,N3:27020")

// 查看集群状态
sh.status()

# Step 16: 创建管理员用户（仅 Node 1 执行）
// 继续在 mongos 中执行
admin = db.getSiblingDB("admin")
admin.createUser({
  user: "admin",
  pwd: "admin",
  roles: [{ role: "root", db: "admin" }]
})

# Step 17: 验证集群完整状态
// 查看分片列表
db.adminCommand({ listShards: 1 })

// 查看详细状态
sh.status()

# Phase 8: 测试分片功能
mongosh --host 127.0.0.1 --port 27017 -u admin -p admin
// 启用数据库分片
sh.enableSharding("ycsb")
// 对集合进行分片
sh.shardCollection("ycsb.usertable", { _id: "hashed" })

// 插入测试数据
use ycsb
for (var i = 0; i < 1000; i++) {
  db.usertable.insertOne({ _id: "user" + i, field0: "value" + i })
}

// 查看数据分布
db.usertable.getShardDistribution()

# 快速验证清单
# 检查所有进程
ps aux | grep mongo
ss -tlnp | grep -E '27017|27018|27019|27020'
