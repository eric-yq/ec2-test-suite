#!/bin/bash

SUT_NAME=${1}
echo "$0: Install SUT_NAME: ${SUT_NAME}"

install_public_tools(){
# 	$PKGCMD update -y
# 	$PKGCMD1 install -y epel
	$PKGCMD install -y git irqbalance python3-pip
	pip3 install dool
	systemctl enable irqbalance --now
}
os_configure(){
	sysctl -w net.core.somaxconn=65535
	sysctl -w net.core.rmem_max=16777216
	sysctl -w net.core.wmem_max=16777216
	sysctl -w net.core.netdev_max_backlog=200000 # 增大接收队列长度（减少丢包）
	sysctl -w net.core.netdev_budget=60000       # 每次软中断处理的最大数据包数
	sysctl -w net.core.netdev_budget_usecs=8000  # 每次软中断的最大时间（微秒）
	sysctl -w net.ipv4.tcp_tw_reuse=1
	sysctl -w net.ipv4.tcp_fastopen=3
	sysctl -w net.ipv4.tcp_congestion_control=bbr
	sysctl -w net.ipv4.ip_local_port_range="1024 65535"
	sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
	sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"
	sysctl -w fs.file-max=1000000
	ulimit -n 1000000
	echo never > /sys/kernel/mm/transparent_hugepage/enabled
}
install_nginx(){
	$PKGCMD1 install -y ${NGINX_PKG_NAME}
}
init_start_nginx(){
	##
	echo "nothing to do  ."
}
modify_nginxcnf(){
	## 修改配置文件
    cp ${NGINX_CONF} ${NGINX_CONF}.bak
	cat << EOF > ${NGINX_CONF}
user root;
worker_processes auto;
worker_rlimit_nofile 1234567;
pid /run/nginx.pid;

events {
    use epoll;
    multi_accept on;
    worker_connections 65535;
}

http {
    access_log   off;
    include      /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile     on;
    tcp_nopush   on;
    tcp_nodelay  off;
    
    # 增大缓冲区减少分段
    proxy_buffers 256 16k;  # 256 个 16KB 缓冲区
    proxy_buffer_size 32k;
    
    # 静态文件缓存
    open_file_cache max=100000 inactive=60s;
    open_file_cache_valid 90s;
    open_file_cache_min_uses 2;
    
    gzip on;
    gzip_min_length 1k;
    gzip_comp_level 3;
	gzip_disable "msie6";
	gzip_vary on;
	gzip_proxied any;
	gzip_buffers 16 8k;
	gzip_http_version 1.1;
	gzip_types application/atom+xml application/geo+json application/javascript application/x-javascript application/json application/ld+json application/manifest+json application/rdf+xml application/rss+xml application/xhtml+xml application/xml font/eot font/otf font/ttf image/svg+xml text/css text/javascript text/plain text/xml;
    
    keepalive_timeout  300s;     
    keepalive_requests 1000000;
    
    server {
        listen       80;
        root         /usr/share/nginx/html;
        
        # 用于 GET 请求
		location /get {
			root /usr/share/nginx/html;
			index index.html;
			access_log off;  # 提高性能
		}
		
		# 用于 POST 请求
		location /post {
			client_body_buffer_size 128k;
			client_max_body_size 128k;
			access_log off;  # 提高性能
		
			# 简单返回 200 OK
			return 200;
		}
    
    }
}
EOF
    systemctl enable  ${NGINX_SERVICE}
    systemctl restart ${NGINX_SERVICE}
	systemctl status  ${NGINX_SERVICE}
	
	## nginx（web 服务器）生成静态资源
	cd /usr/share/nginx/html
	mkdir -p get
	cp index.html get/
	
	touch 0kb.bin
	dd if=/dev/zero of=1kb.bin  bs=1KB  count=1
	dd if=/dev/zero of=10kb.bin bs=10KB count=1
	dd if=/dev/zero of=100kb.bin bs=100KB count=1
	dd if=/dev/zero of=1mb.bin  bs=1MB  count=1
	
	wget http://www.phoronix-test-suite.com/benchmark-files/http-test-files-1.tar.xz
	tar xf http-test-files-1.tar.xz 
	mv -f http-test-files/* .
}

# 主要流程

## 获取OS 、CPU 架构信息。
OS_NAME=$(egrep ^NAME /etc/os-release | awk -F "\"" '{print $2}')
OS_VERSION=$(egrep ^VERSION_ID /etc/os-release | awk -F "\"" '{print $2}') 

if   [[ "$OS_NAME" == "Amazon Linux" ]]; then
	if   [[ "$OS_VERSION" == "2" ]]; then
		PKGCMD=yum
		PKGCMD1=amazon-linux-extras
		NGINX_PKG_NAME="nginx1"
	elif [[ "$OS_VERSION" == "2023" ]]; then
		PKGCMD=dnf
		PKGCMD1=dnf
		NGINX_PKG_NAME="nginx"
	else
		echo "$0: $OS_NAME $OS_VERSION not supported"
		exit 1
	fi
		
	# NGINX conf
	NGINX_SERVICE="nginx"
	NGINX_CONF="/etc/nginx/nginx.conf"

elif [[ "$OS_NAME" == "Ubuntu" ]]; then
	PKGCMD=apt
	PKGCMD1=apt
	NGINX_PKG_NAME="nginx"
	# nginx conf
	NGINX_SERVICE="nginx"
	NGINX_CONF="/etc/nginx/nginx.conf"

else
	echo "$0: $OS_NAME not supported"
	exit 1
fi

install_public_tools
os_configure
install_nginx
modify_nginxcnf
	

