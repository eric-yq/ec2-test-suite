#!/bin/bash

SUT_NAME=${1}
echo "$0: Install SUT_NAME: ${SUT_NAME}"

## 获取OS 、CPU 架构信息。
OS_NAME=$(egrep ^NAME /etc/os-release | awk -F "\"" '{print $2}')
# OS_ID=$(egrep "^ID=" /etc/os-release | awk -F "\"" '{print $2}') 
OS_VERSION=$(egrep ^VERSION_ID /etc/os-release | awk -F "\"" '{print $2}') 
ARCH=$(lscpu | grep Architecture | awk -F " " '{print $NF}') 
PN=$(dmidecode -s system-product-name | tr ' ' '_')

if   [[ "$OS_NAME" == "Amazon Linux" ]] && [[ "$OS_VERSION" == "2" ]]; then
	PKGCMD=yum
	PKGCMD1=amazon-linux-extras
	
	# redis conf
	REDIS_PKG_NAME="redis6"
	REDIS_SERVICE="redis"
	REDIS_CONF="/etc/redis/redis"
	
elif [[ "$OS_NAME" == "Amazon Linux" ]] && [[ "$OS_VERSION" == "2023" ]]; then
	PKGCMD=dnf
	PKGCMD1=dnf
	
	# redis conf
	REDIS_PKG_NAME="redis6"
	REDIS_SERVICE="redis6"
	REDIS_CONF="/etc/redis6/redis6"

elif [[ "$OS_NAME" == "Ubuntu" ]] || [[ "$OS_NAME" == "Debian GNU/Linux" ]]; then
	PKGCMD=apt
	PKGCMD1=apt
	
	# redis conf
	REDIS_PKG_NAME="redis-server=6:6.2.11-1rl1~$(lsb_release -cs)1 redis-tools=6:6.2.11-1rl1~$(lsb_release -cs)1"
	REDIS_SERVICE="redis-server"
	REDIS_CONF="/etc/redis/redis"
	# add redis repository for ubuntu/debian
	apt update
	apt install -y gpg
	curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
	echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
	apt update

else
	echo "$OS_NAME not supported"
	exit 1
fi
	
install_public_tools(){
	$PKGCMD update -y
	$PKGCMD1 install -y epel
	$PKGCMD install -y dmidecode net-tools dstat htop nload
# 	$PKGCMD install -y stress-ng
# 	$PKGCMD install -y perf
	$PKGCMD install -y git
}

# Redis 6.x: 
install_redis(){
    $PKGCMD1 install -y ${REDIS_PKG_NAME}
    cp ${REDIS_CONF}.conf ${REDIS_CONF}.conf.bak
    IPADDR=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | awk -F " " '{print $2}')
    sed -i "s/bind 127.0.0.1/bind ${IPADDR}/g" ${REDIS_CONF}.conf
    sed -i "s/daemonize no/daemonize yes/g" ${REDIS_CONF}.conf
    sed -i "s/protected-mode yes/protected-mode no/g" ${REDIS_CONF}.conf
    echo "io-threads-do-reads yes" >> ${REDIS_CONF}.conf
    let IO_THREADS=$(nproc)-1
    echo "io-threads ${IO_THREADS}"  >> ${REDIS_CONF}.conf
    # for cluster
    echo "cluster-enabled yes" >> ${REDIS_CONF}.conf
	echo "cluster-config-file cluster-nodes.conf" >> ${REDIS_CONF}.conf
	echo "cluster-node-timeout 15000" >> ${REDIS_CONF}.conf
}
start_redis(){
    ## 启动 redis
    systemctl enable  ${REDIS_SERVICE}
    systemctl restart ${REDIS_SERVICE}
    systemctl status  ${REDIS_SERVICE}
}

## 主要流程
install_public_tools

install_redis
start_redis
