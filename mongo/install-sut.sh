#!/bin/bash

SUT_NAME=${1}
echo "$0: Install SUT_NAME: ${SUT_NAME}"

install_public_tools(){
# 	$PKGCMD update -y
	$PKGCMD1 install -y epel
	$PKGCMD install -y dmidecode net-tools dstat htop nload
	
	## OS CONFIG
	sysctl -w vm.max_map_count = 98000
	sysctl -w kernel.pid_max = 64000
	sysctl -w kernel.threads-max = 64000
	sysctl -w vm.max_map_count=128000
	sysctl -w net.core.somaxconn=65535
}
install_mongo(){
    $PKGCMD install -y mongodb-org
    MONGO_USER_GROUP=$(grep mongo /etc/passwd | awk -F ":" '{print $1}')
    
    mkdir -p /data/mongodb
	chown -R ${MONGO_USER_GROUP}:${MONGO_USER_GROUP} /data/mongodb
	cp ${MONGO_CONF} ${MONGO_CONF}.bak
# 	sed -i 's/\/var\/lib\/mongodb/\/var\/lib\/mongo/g' ${MONGO_CONF}
# 	sed -i 's/\/var\/lib\/mongo/\/data\/mongodb/g' ${MONGO_CONF}
	
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
  journal:
    enabled: true
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
	cp ${MONGO_CONF} ${MONGO_CONF}.bak.1
# 	sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/g' ${MONGO_CONF}
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
PN=$(dmidecode -s system-product-name | tr ' ' '_')
MONGO_XY="6.0"

echo "$0: 1. OS is ${OS_NAME} ${OS_VERSION} "

if [[ "$OS_NAME" == "Amazon Linux" ]]; then
    if [[ "$OS_VERSION" == "2" ]]; then
		PKGCMD=yum
		PKGCMD1=amazon-linux-extras
		cat << EOF > /etc/yum.repos.d/mongodb-org-${MONGO_XY}-${ARCH}.repo
[mongodb-org-${MONGO_XY}-${ARCH}]
name=MongoDB Repository for ${MONGO_XY}-${ARCH}
baseurl=https://repo.mongodb.org/yum/amazon/2/mongodb-org/${MONGO_XY}/${ARCH}/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-${MONGO_XY}.asc
EOF
    elif [[ "$OS_VERSION" == "2023" ]]; then
		PKGCMD=dnf
		PKGCMD1=dnf
		echo "$0: $OS_NAME $OS_VERSION not supported"
		exit 1
    else
		echo "$0: $OS_NAME $OS_VERSION not supported"
		exit 1
	fi

	# mongo conf
	MONGO_SERVICE="mongod"
	MONGO_CONF="/etc/mongod.conf"

elif [[ "$OS_NAME" == "Ubuntu" ]]; then
	PKGCMD=apt
	PKGCMD1=apt

	if [[ "$OS_VERSION" == "20.04" ]]; then
		UBUNTU_RELEASE=focal

	elif [[ "$OS_VERSION" == "22.04" ]]; then
		UBUNTU_RELEASE=jammy

	else
		echo "$0: $OS_NAME $OS_VERSION not supported"
		exit 1
	fi
	
	${PKGCMD} install gnupg -y
	wget -qO - https://www.mongodb.org/static/pgp/server-${MONGO_XY}.asc | apt-key add -
	echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu ${UBUNTU_RELEASE}/mongodb-org/${MONGO_XY} multiverse" > /etc/apt/sources.list.d/mongodb-org-${MONGO_XY}.list
	${PKGCMD} update
		
	# mongo conf
	MONGO_SERVICE="mongod"
	MONGO_CONF="/etc/mongod.conf"

else
	echo "$OS_NAME not supported"
	exit 1
fi

# mongo installation
install_public_tools
sleep 30
install_mongo
init_start_mongo
