#!/bin/bash

SUT_NAME=${1}
INSTANCE_IP_WEB1=${2}
INSTANCE_IP_WEB2=${3}

echo "$0: Install SUT_NAME: ${SUT_NAME}"
echo "$0: INSTANCE_IP_WEB1: ${INSTANCE_IP_WEB1}"
echo "$0: INSTANCE_IP_WEB2: ${INSTANCE_IP_WEB2}"

install_public_tools(){
	$PKGCMD update -y
	$PKGCMD1 install -y epel
	$PKGCMD install -y dmidecode net-tools htop
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
	echo "nothing to do ."
}
modify_nginxcnf(){
	## 修改配置文件
    cp ${NGINX_CONF} ${NGINX_CONF}.bak
    ### 生成密钥
    NGINX_CONF_DIR=$(dirname ${NGINX_CONF})
	openssl req -new -x509 -newkey rsa:2048 -nodes \
	  -subj "/C=US/ST=Denial/L=Chicago/O=Dis/CN=127.0.0.1" \
	  -keyout ${NGINX_CONF_DIR}/rsa-key.key \
	  -out ${NGINX_CONF_DIR}/rsa-cert.crt
	cat << EOF > ${NGINX_CONF}
user root;
worker_processes auto;
worker_rlimit_nofile 1234567;
pid /run/nginx.pid;

events {
    use epoll;
    worker_connections 10240;
    multi_accept on;
    accept_mutex on;
}

http {
    access_log          off;
    include             ${NGINX_CONF_DIR}/mime.types;
    default_type        application/octet-stream;
    sendfile            on;
    tcp_nopush          on;

    # RPS tests
    keepalive_timeout   300s;
    keepalive_requests  1234567890;
    
    # SSL/TLS TPS tests
    # keepalive_timeout 0;
    # keepalive_requests 1;
        
    ## 负载均衡配置，后端服务器组配置
    upstream nginx-webserver-group {
        server ${INSTANCE_IP_WEB1}  weight=100;
        server ${INSTANCE_IP_WEB2}  weight=100;
    }

    server {
        listen       80;
        listen       443 ssl backlog=102400 ;
        
        ssl_certificate     ${NGINX_CONF_DIR}/rsa-cert.crt;
        ssl_certificate_key ${NGINX_CONF_DIR}/rsa-key.key;
        ssl_ciphers         ECDHE-RSA-AES256-GCM-SHA384;
        ssl_session_tickets off;
        ssl_session_cache   off;

        root         /usr/share/nginx/html;
        
        ## 负载均衡配置
        location / {
            proxy_pass http://nginx-webserver-group;
        }
    }
}
EOF
    systemctl enable  ${NGINX_SERVICE}
    systemctl restart ${NGINX_SERVICE}
	systemctl status  ${NGINX_SERVICE}
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
		
	# mysql conf
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
	

