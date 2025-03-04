#!/bin/bash

SUT_NAME=${1}
INSTANCE_IP_WEB1=${2}
INSTANCE_IP_WEB2=${3}

echo "$0: Install SUT_NAME: ${SUT_NAME}"
echo "$0: INSTANCE_IP_WEB1: ${INSTANCE_IP_WEB1}"
echo "$0: INSTANCE_IP_WEB2: ${INSTANCE_IP_WEB2}"

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
	sysctl -w net.ipv4.tcp_max_syn_backlog=65535
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
    worker_connections 65535;
    multi_accept on;
    accept_mutex off;
}

http {
    access_log          off;
    include             ${NGINX_CONF_DIR}/mime.types;
    default_type        application/octet-stream;
    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         off;
    
    # 增大缓冲区减少分段
    proxy_buffers 256 16k;  # 256 个 16KB 缓冲区
    proxy_buffer_size 32k;
    
    # 增加缓冲区大小
    client_body_buffer_size 128k;
    client_max_body_size 100m;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 4k;
    output_buffers 1 32k;
    postpone_output 1460;

    # RPS tests     
    keepalive_timeout   300s;
    keepalive_requests  1000000;
    
    # SSL/TLS TPS tests
    # keepalive_timeout 0;
    # keepalive_requests 1;
    
    types_hash_max_size 2048;
    types_hash_bucket_size 128;
    
##################
    # SSL/TLS 优化
    ssl_session_cache shared:SSL:50m;
    ssl_session_timeout 1h;
    ssl_session_tickets off;    # 禁用 Session Tickets（避免密钥轮换问题）
    ssl_buffer_size 4k;         # 减少 SSL 写入延迟

    # 加密算法优化
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers on;
    ssl_ecdh_curve X25519:secp384r1;  # 高效椭圆曲线
##################
      
    ## 负载均衡配置，后端服务器组配置
    upstream nginx-webserver-group {
        server ${INSTANCE_IP_WEB1}  weight=100;
        server ${INSTANCE_IP_WEB2}  weight=100;
        keepalive 64;           # 保持长连接
    }

    server {
        listen       80;
        listen       443 ssl backlog=102400 ;
        http2        on;
        
        ssl_certificate     ${NGINX_CONF_DIR}/rsa-cert.crt;
        ssl_certificate_key ${NGINX_CONF_DIR}/rsa-key.key;

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
	

