#!/bin/bash

SUT_NAME=${1}
echo "$0: Install SUT_NAME: ${SUT_NAME}"

## 获取OS 、CPU 架构信息。
OS_NAME=$(egrep ^NAME /etc/os-release | awk -F "\"" '{print $2}')
OS_VERSION=$(egrep ^VERSION_ID /etc/os-release | awk -F "\"" '{print $2}') 

if  [[ "$OS_NAME" == "Amazon Linux" ]] && [[ "$OS_VERSION" == "2023" ]]; then
	echo "$0: OS is $OS_NAME $OS_VERSION . "
else
	echo "$0: $OS_NAME not supported"
	exit 1
fi
	
install_public_tools(){
	yum install -y python3-pip
	pip3 install dool
	yum install -y docker
	systemctl enable docker
	systemctl start docker
}

## 多线程配置
install_valkey(){
    docker pull valkey/valkey:8.0.1

	## 获取 CPU数 和 内存容量
	CPU_CORES=$(nproc)
	MEM_TOTAL_GB=$(free -g |grep Mem | awk -F " " '{print $2}')

	## 变量计算
	let XXX=${MEM_TOTAL_GB}*80/100
# 	let YYY=${CPU_CORES}-2
# 	let YYY=${CPU_CORES}*50/100
    let YYY=3

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
}

## 单线程配置
install_valkey1(){
    docker pull valkey/valkey:8.0.1
    
	## 获取 CPU数 和 内存容量
	CPU_CORES=$(nproc)
	MEM_TOTAL_GB=$(free -g |grep Mem | awk -F " " '{print $2}')

	## 变量计算
	let XXX=${MEM_TOTAL_GB}*80/100

	# 生成配置文件
	cat > /root/valkey.conf << EOF
	port 6379
	bind 0.0.0.0
	protected-mode no
	maxmemory ${XXX}gb
	maxmemory-policy allkeys-lru
EOF
}

start_valkey(){

    sysctl vm.overcommit_memory=1
    
    # 计算启动 pods 的数量，VCPU数的75%，16 核->12 pods
    CPU_CORES=$(nproc)
    let PODS_NUMBER=${CPU_CORES}*75/100
    for i in $(seq 1 $PODS_NUMBER)
    do
        let PORT=${i}+8880
	    docker run -d --name valkey-$PORT \
	      -p $PORT:6379 \
	      -v /root/valkey.conf:/etc/valkey/valkey.conf \
	      valkey/valkey:8.0.2 \
	      valkey-server /etc/valkey/valkey.conf
    done
    
    docker ps -a 
}

## 主要流程
install_public_tools
# install_valkey
install_valkey1
start_valkey
