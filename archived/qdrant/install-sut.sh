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
	
elif [[ "$OS_NAME" == "Amazon Linux" ]] && [[ "$OS_VERSION" == "2023" ]]; then
	PKGCMD=dnf
	PKGCMD1=dnf

elif [[ "$OS_NAME" == "Ubuntu" ]] || [[ "$OS_NAME" == "Debian GNU/Linux" ]]; then
	PKGCMD=apt
	PKGCMD1=apt

else
	echo "$0: $OS_NAME not supported"
	exit 1
fi
	
install_dependence(){
	$PKGCMD update -y	
	cd /root/
	$PKGCMD  install -y docker git
	systemctl start docker
	VER="v2.29.2"
	ARCH=$(arch)
	curl -SL https://github.com/docker/compose/releases/download/$VER/docker-compose-linux-${ARCH} -o /usr/bin/docker-compose
	chmod +x /usr/bin/docker-compose
}

# SUT: 
install_sut(){
    cd /root/
    git clone https://github.com/qdrant/vector-db-benchmark.git
}

start_sut(){
    ## 启动
    ENGINE_CONFIG_NAME="qdrant-single-node"
	cd /root/vector-db-benchmark/engine/servers/$ENGINE_CONFIG_NAME
	docker-compose up -d
	## 查看状态
	docker-compose ps
}

## 主要流程
install_dependence
install_sut
start_sut
