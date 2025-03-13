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
	
	#OS优化
	# 禁用透明大页面（Transparent Huge Pages）
    echo never > /sys/kernel/mm/transparent_hugepage/enabled
    echo never > /sys/kernel/mm/transparent_hugepage/defrag

    # 添加到 /etc/rc.local 以便在启动时生效
    cat >> /etc/rc.local << EOF
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
  echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
  echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi
EOF
    chmod +x /etc/rc.local

    cat >> /etc/sysctl.conf << EOF
# 最大打开文件描述符数量
fs.file-max = 1000000

# 提高 TCP 缓冲区限制
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65536
net.ipv4.tcp_max_syn_backlog = 65536

# 启用 TCP 窗口缩放
net.ipv4.tcp_window_scaling = 1

# 增加 TCP 最大和默认缓冲区大小
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# 启用 TCP 快速打开
net.ipv4.tcp_fastopen = 3

# 优化 TCP 连接处理
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1

# 优化本地端口范围
net.ipv4.ip_local_port_range = 10000 65535

# 增加系统内存溢出处理
vm.overcommit_memory = 1

# 禁用 swap 交换
vm.swappiness = 0
EOF

    # 应用设置
    sysctl -p

    cat >> /etc/security/limits.conf << EOF
# 为 valkey 用户或运行 valkey 的用户设置限制
valkey soft nofile 1000000
valkey hard nofile 1000000
valkey soft nproc 65535
valkey hard nproc 65535

# 如果使用 root 或其他用户运行，也需要设置
root soft nofile 1000000
root hard nofile 1000000
root soft nproc 65535
root hard nproc 65535

# 对所有用户设置
* soft nofile 1000000
* hard nofile 1000000
EOF

    echo 1 > /proc/sys/vm/overcommit_memory
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
    
    # 计算启动 pods 的数量，VCPU数的50%，16 核->8 pods
    CPU_CORES=$(nproc)
    let PODS_NUMBER=${CPU_CORES}*50/100
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

start_dool_monitor(){
    
}

## 主要流程
install_public_tools
# install_valkey
install_valkey1
start_valkey
