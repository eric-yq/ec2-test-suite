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
# 	yum install -y docker
# 	systemctl enable docker
# 	systemctl start docker
	
	echo "vm.overcommit_memory = 1" >> /etc/sysctl.conf
	sysctl vm.overcommit_memory=1
}

install_valkey(){
    # docker pull valkey/valkey:7.2.8
    yum install -y valkey
    systemctl stop valkey
    systemctl enable valkey
    
	## 获取 CPU数 和 内存容量
	CPU_CORES=$(nproc)
	MEM_TOTAL_GB=$(free -g |grep Mem | awk -F " " '{print $2}')

	## 变量计算
	let XXX=${MEM_TOTAL_GB}*80/100
# 	let YYY=${CPU_CORES}-2
    let YYY=${CPU_CORES}*50/100

	# 生成配置文件
	cat > /etc/valkey/valkey.conf << EOF
	port 6379
	bind 0.0.0.0
	protected-mode no
	daemonize yes
	maxmemory ${XXX}gb
	maxmemory-policy allkeys-lru
	io-threads $YYY	
	io-threads-do-reads yes
	# for cluster
	cluster-enabled yes
	cluster-config-file cluster-nodes.conf
	cluster-node-timeout 5000
EOF
}

start_valkey(){
# 	docker run -d --name valkey \
# 	  -p 6379:6379 \
# 	  -v /root/valkey.conf:/etc/valkey/valkey.conf \
# 	  valkey/valkey:7.2.8 \
# 	  valkey-server /etc/valkey/valkey.conf
    
#     valkey-server /root/valkey.conf

    systemctl restart valkey
    
    sleep 5 && valkey-cli info
}

## 主要流程
install_public_tools
install_valkey
start_valkey
