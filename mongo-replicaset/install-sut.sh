#!/bin/bash

SUT_NAME=${1}
echo "$0: Install SUT_NAME: ${SUT_NAME}"

install_public_tools(){
	$PKGCMD update -y
	$PKGCMD1 install -y epel
	$PKGCMD install -y dmidecode net-tools dstat htop nload
# 	$PKGCMD install -y stress-ng
# 	$PKGCMD install -y perf
	$PKGCMD install -y git
}

install_mongo(){
    $PKGCMD install -y mongodb-org
    MONGO_USER_GROUP=$(grep mongo /etc/passwd | awk -F ":" '{print $1}')
    
    mkdir -p /data/mongodb
	chown -R ${MONGO_USER_GROUP}:${MONGO_USER_GROUP} /data/mongodb
	cp ${MONGO_CONF} ${MONGO_CONF}.bak
# 	sed -i 's/\/var\/lib\/mongodb/\/var\/lib\/mongo/g' ${MONGO_CONF}
# 	sed -i 's/\/var\/lib\/mongo/\/data\/mongodb/g' ${MONGO_CONF}

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
      cacheSizeGB: 31
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

	## 鉴权和复制集配置
	cp ${MONGO_CONF} ${MONGO_CONF}.bak.1
# 	sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/g' ${MONGO_CONF}
	cat << EOF >> ${MONGO_CONF}
security:
  authorization: enabled
  keyFile: /etc/mongod.keyfile
replication:
  replSetName: rs0gv2mongo
  oplogSizeMB: 40000
EOF
	## 密钥文件
	cat << EOF > /etc/mongod.keyfile
5yw3oYmQ046VQSYOApETZs+lkL/oed14OyHrmm7NUHUNYMoDSirlYmdY81OhhOxV
RIdGISTSbK3QyXsMDXoQKHOWhKBeOI8qN/y97UeWDGG6HDsd9lsjU07hVdLcGy8+
6gYmYBxMe+ZN50umbF9bcl0E2T6D/vNzIqgi6m4VHNbdvW718/pv9m2d5g8AmtkZ
XLsP4xa6FUG9N5hcls3BvrbKkzCasEzWqWbwpKyi8zF+aoWkDAnZUqT/3aZE3KlD
ZmoWen0O6od0+9UU2zAsRxHbh563zFSIpJDWVViElyW/j+3fsyli87TN+eVfHhw2
GQcUtIQvBgVb5BLpnVh6x6v92Bo1r4Cyl9rVXZtAPI5gwERPwfSuHcSSo9Q9ZP7X
e+tVspWmFnzoFQDa/chGLs6VbZiU/T3JcZ1oCG10SilvqpI4BHCSwpw8iXpaCtQM
1fGExZDcWVLjO+9FvnT+0+xY9kMUcAwKPL8j0bs6nWFdBakdm06/Y+LXViTt7KCz
WPCQbT+vszp4AIhkh/57LokekeMyBUpwFZroyaAlM5vTnj16wJzXIOuuOwuHgJ2b
tmxXTAQuajiOlPlz0R1+Kt84dXUrg84SxUJxeBVp0FnGSKjpeTqKmyReXpZMQ3gu
gmsimnBEk0/0L9EuTjOL6u/C8OSab5NqZ4yfAF9c76ihCHfRJamdzbAvLXTmHOuv
rKBVgbSWch+rGKC3akmB+p1pzbkyiMQG1X676/K6PwkCAKd6brcfLeFaB2Tjs3GB
evMCQdraLxFAI/Nz16QfQVMYd0i4VH6iwWBb66l4tznylVZNhRzTI+wJIL4Up/dR
Q66FBsLLBLdNMW/gyXB33eXt5EtUX9VuUwy3+VVH3ukn9WJS1lNnBTb/V3XldizM
JQi4h9xl/CkcnJuJ21ufYOLrsey6h8Sj7IwKQaOTC3szMS9hJ/IKUq8tTJIWrLC4
Rt3ZCpxHaIi+PGl0vTaLqy93e7YYnzfIEsn0FCjjRlG18KIM
EOF

	chmod 400 /etc/mongod.keyfile
	MONGO_USER_GROUP=$(grep mongo /etc/passwd | awk -F ":" '{print $1}')
	chown ${MONGO_USER_GROUP}. /etc/mongod.keyfile
	
	systemctl restart ${MONGO_SERVICE}
	systemctl status ${MONGO_SERVICE}
}

# 主要流程

## 获取OS 、CPU 架构信息。
OS_NAME=$(egrep ^NAME /etc/os-release | awk -F "\"" '{print $2}')
# OS_ID=$(egrep "^ID=" /etc/os-release | awk -F "\"" '{print $2}') 
OS_VERSION=$(egrep ^VERSION_ID /etc/os-release | awk -F "\"" '{print $2}') 
ARCH=$(lscpu | grep Architecture | awk -F " " '{print $NF}') 
PN=$(dmidecode -s system-product-name | tr ' ' '_')
IPADDR=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | awk -F " " '{print $2}')

ARCH=$(lscpu | grep Architecture | awk -F " " '{print $NF}')   ## aarch64, x86_64
MONGO_XY="6.0"
		
if   [[ "$OS_NAME" == "Amazon Linux" ]]; then
	if   [[ "$OS_VERSION" == "2" ]]; then
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

	elif [[ "$0: $OS_VERSION" == "2023" ]]; then
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

	if   [[ "$OS_VERSION" == "20.04" ]]; then
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
	
# elif [[ "$OS_NAME" == "CentOS Linux" ]] && [[ "$OS_VERSION" == "7" ]]; then
# 	install_centos7_dependencies
# 
# elif [[ "$OS_NAME" == "CentOS Stream" ]] && [[ "$OS_VERSION" == "8" ]]; then
# 	install_centos8_dependencies
# 
# elif [[ "$OS_NAME" == "CentOS Stream" ]] && [[ "$OS_VERSION" == "9" ]]; then
# 	install_centos9_dependencies

else
	echo "$0: $OS_NAME not supported"
	exit 1
fi

# mysql installation
install_public_tools
install_mongo
init_start_mongo

# ## 启动监控、上传到 S3 --- BEGIN
cd ~
dstat -cmndryt -D nvme0n1p1 --output /root/dstat.csv 60 90

DATA_DIR=~/mongo_benchmark_${PN}_${IPADDR}
mkdir -p ${DATA_DIR}
cp /var/log/cloud-init-output.log /root/dstat.csv ${DATA_DIR}/
tar czfP ${DATA_DIR}.tar.gz ${DATA_DIR}
