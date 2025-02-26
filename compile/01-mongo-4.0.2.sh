#!/bin/bash

## 实例名称： AB23-Demo-MongoDB4.0.12-编译-AL2
## 实例规格： r6g.16xlarge
## 编译时间： 20 分钟
## 在 /varlog/cloud-init-out.log 查看执行过程

cd /root/

## 安装开发工具
yum update -y 
amazon-linux-extras install -y epel
yum install -y gcc10 gcc10-c++
yum install -y dstat htop nload iotop

## 设置 gcc 和 g++ 版本
alternatives --install /usr/bin/gcc gcc /usr/bin/gcc10-cc  100
alternatives --install /usr/bin/g++ g++ /usr/bin/gcc10-c++ 100
gcc --version
g++ --version

## 安装其他依赖包
yum install -y openssl-devel libffi-devel libcurl-devel python3-devel

## 升级 pip3
wget -q https://bootstrap.pypa.io/pip/get-pip.py
python3 get-pip.py

## 安装 pip2 和依赖包
wget -q https://bootstrap.pypa.io/pip/2.7/get-pip.py -O get-pip-2.7.py
python2 get-pip-2.7.py

## Enable Transparent Huge Pages (THP) 
echo always > /sys/kernel/mm/transparent_hugepage/enabled

## 下载 MongoDB 4.0.12 源码包
cd /root
MONGODB_VERSION="4.0.12"
wget -q https://github.com/mongodb/mongo/archive/r${MONGODB_VERSION}.tar.gz \
  --no-check-certificate -O mongo-r${MONGODB_VERSION}.tar.gz 
tar -xf mongo-r${MONGODB_VERSION}.tar.gz && cd mongo-r${MONGODB_VERSION}

### 自动检查并解决依赖关系
pip2 install requirements_parser
pip2 install typing
pip2 install cheetah
pip3 install -r buildscripts/requirements.txt

## Graviton 2 实例编译命令，
python2 buildscripts/scons.py MONGO_VERSION=${MONGODB_VERSION} all \
  -j$(nproc) --disable-warnings-as-errors \
  CFLAGS="-O3 -mcpu=neoverse-n1 -fsigned-char" \
  CXXFLAGS="-O3 -mcpu=neoverse-n1"

## 编译完成后安装到指定目录：
python2 buildscripts/scons.py MONGO_VERSION=${MONGODB_VERSION} install \
  -j$(nproc) --disable-warnings-as-errors \
  CFLAGS="-O3 -mcpu=neoverse-n1 -fsigned-char" \
  CXXFLAGS="-O3 -mcpu=neoverse-n1" \
  --prefix=/usr/local/mongo
  
## 删除调试信息，缩减可执行文件的大小。
cd /usr/local/mongo/bin
strip mongos
strip mongod
strip mongo

rm -rf /root/mongo-r${MONGODB_VERSION}

## 安装 Mongo Tools: Mongo Shell 和 MongoDB Database Tools
cd ~
wget -q https://downloads.mongodb.com/compass/mongodb-mongosh-1.8.0.aarch64.rpm
wget -q https://fastdl.mongodb.org/tools/db/mongodb-database-tools-amazon2-aarch64-100.7.0.rpm
yum localinstall -y mongodb-mongosh-1.8.0.aarch64.rpm mongodb-database-tools-amazon2-aarch64-100.7.0.rpm

## 将 MongoDB 安装路径加入到 PATH
echo "export PATH=$PATH:/usr/local/mongo/bin" >>  /etc/profile
source /etc/profile
mongod --version

## 创建配置文件:  
mkdir -p /data/mongodb /var/log/mongodb
cat << EOF > /etc/mongod.conf
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongo.log
storage:
  dbPath: /data/mongodb
  journal:
    enabled: true
processManagement:
  timeZoneInfo: /usr/share/zoneinfo
net:
  port: 27017
  bindIp: 0.0.0.0
EOF

## 启动 
mongod --fork --config /etc/mongod.conf

## 创建 root 用户，密码为 gv2mongo
mongo << EOF
use admin
db.createUser({user:'root',pwd:'gv2mongo',roles:['root']});
show users
exit
EOF

## 停止 MongoDB 
mongod --shutdown --config /etc/mongod.conf

## 开启鉴权
cp /etc/mongod.conf /etc/mongod.conf.bak.1
sed -i 's/port: 27017/port: 37017/g' /etc/mongod.conf
echo "security:" >> /etc/mongod.conf
echo "  authorization: enabled" >> /etc/mongod.conf

mongod --fork --config /etc/mongod.conf

# ===================== 下面的操作在 MongoDB 启动好之后手工执行 ===================== 
## 验证
ps -ef | grep mongod
netstat -anpt | grep mongod

## 加载 sample data
wget -q https://atlas-education.s3.amazonaws.com/sampledata.archive
# mongorestore --port 37017 --archive=sampledata.archive --username root --password gv2mongo
# 
# mongosh --port 37017 -u root -p gv2mongo << EOF
# show dbs
# exit
# EOF