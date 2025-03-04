#!/bin/bash

SUT_NAME=${1}
echo "$0: Install SUT_NAME: ${SUT_NAME}"

install_public_tools(){
	$PKGCMD update -y
	$PKGCMD1 install -y epel
	$PKGCMD install -y dmidecode htop
	$PKGCMD install -y git 
}
os_configure(){
	sysctl -w net.core.somaxconn=65535
	sysctl -w net.core.rmem_max=8388607
	sysctl -w net.core.wmem_max=8388607
	sysctl -w net.ipv4.tcp_max_syn_backlog=65535
	sysctl -w net.ipv4.ip_local_port_range="1024 65535"
	sysctl -w net.ipv4.tcp_rmem="4096 8338607 8338607"
	sysctl -w net.ipv4.tcp_wmem="4096 8338607 8338607"
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
    worker_connections 10240;
}

http {
    access_log   off;
    include      /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile     on;
    tcp_nopush   on;
    
    keepalive_timeout  300s;     
    keepalive_requests 1234567890;
    
    server {
        listen       80;
        root         /usr/share/nginx/html;
        
		gzip on;
		gzip_disable "msie6";
		gzip_vary on;
		gzip_proxied any;
		gzip_comp_level 5;
		gzip_buffers 16 8k;
		gzip_http_version 1.1;
		gzip_min_length 1k;
		gzip_types application/atom+xml application/geo+json application/javascript application/x-javascript application/json application/ld+json application/manifest+json application/rdf+xml application/rss+xml application/xhtml+xml application/xml font/eot font/otf font/ttf image/svg+xml text/css text/javascript text/plain text/xml;
    }
}
EOF
    systemctl enable  ${NGINX_SERVICE}
    systemctl restart ${NGINX_SERVICE}
	systemctl status  ${NGINX_SERVICE}
	
	## nginx（web 服务器）生成静态资源
	cd /usr/share/nginx/html
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
ARCH=$(lscpu | grep Architecture | awk -F " " '{print $NF}') 
PN=$(dmidecode -s system-product-name | tr ' ' '_')

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
	

