#!/bin/bash

## Only for Amazon Linux 2023

SUT_NAME=${1}
echo "$0: Install SUT_NAME: ${SUT_NAME}"

install_public_tools(){
    yum install -y dmidecode
	  yum install -y epel
	  yum install -y dmidecode net-tools htop git python3-pip
	  pip3 install dool
    
    ## OS CONFIG
    sysctl -w vm.max_map_count=98000
    sysctl -w kernel.pid_max=64000
    sysctl -w kernel.threads-max=64000
    sysctl -w vm.max_map_count=128000
    sysctl -w net.core.somaxconn=65535
}

install_mongo(){
    yum install -y mongodb-mongosh-shared-openssl3
    yum install -y mongodb-org
    MONGO_USER_GROUP=$(grep mongo /etc/passwd | awk -F ":" '{print $1}')
    
    mkdir -p /data/mongodb
    chown -R ${MONGO_USER_GROUP}:${MONGO_USER_GROUP} /data/mongodb
    cp ${MONGO_CONF} ${MONGO_CONF}.bak
	
    ## 设置 cacheSizeGB
    MEM_TOTAL_GB=$(free -g |grep Mem | awk -F " " '{print $2}')
    let XXX=${MEM_TOTAL_GB}*80/100
	
    cat << EOF > ${MONGO_CONF}
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

processManagement:
  timeZoneInfo: /usr/share/zoneinfo

net:
  port: 27017
  bindIpAll: true
  maxIncomingConnections: 65535

operationProfiling:
  mode: off

storage:
  dbPath: /data/mongodb
  directoryPerDB: true
  engine: wiredTiger
  wiredTiger:
    engineConfig:
      cacheSizeGB: ${XXX}
      directoryForIndexes: true
      journalCompressor: snappy
    collectionConfig:
      blockCompressor: snappy
    indexConfig:
      prefixCompression: true

EOF

    systemctl restart ${MONGO_SERVICE}
    systemctl status ${MONGO_SERVICE}
    sleep 5
}

init_start_mongo(){
    ## 创建 root 用户
    mongosh << EOF
use admin
db.createUser({user:'root',pwd:'gv2mongo',roles:['root']});
exit
EOF
    echo "security:" >> ${MONGO_CONF}
    echo "  authorization: enabled" >> ${MONGO_CONF}

    systemctl restart ${MONGO_SERVICE}
    systemctl status ${MONGO_SERVICE}
    
    wget --quiet https://atlas-education.s3.amazonaws.com/sampledata.archive
    mongorestore --archive=sampledata.archive --username root --password gv2mongo
}

# 主要流程

## 获取OS 、CPU 架构信息。
OS_NAME=$(egrep ^NAME /etc/os-release | awk -F "\"" '{print $2}')
OS_VERSION=$(egrep ^VERSION_ID /etc/os-release | awk -F "\"" '{print $2}')
ARCH=$(lscpu | grep Architecture | awk -F " " '{print $NF}')

## 添加 MongoDB Repo
MONGO_XY="8.0"
cat << EOF > /etc/yum.repos.d/mongodb-org-${MONGO_XY}-${ARCH}.repo
[mongodb-org-${MONGO_XY}-${ARCH}]
name=MongoDB Repository for ${MONGO_XY}-${ARCH}
baseurl=https://repo.mongodb.org/yum/amazon/${OS_VERSION}/mongodb-org/${MONGO_XY}/${ARCH}/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-${MONGO_XY}.asc
EOF

# mongo conf
MONGO_SERVICE="mongod"
MONGO_CONF="/etc/mongod.conf"

# mongo installation
install_public_tools
sleep 10
install_mongo
init_start_mongo
