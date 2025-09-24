#!/bin/bash

SUT_NAME="nginx-webserver"
echo "$0: Install SUT_NAME: ${SUT_NAME}"

install_public_tools(){
	$PKGCMD install -y git irqbalance python3-pip
	pip3 install dool
	systemctl enable irqbalance --now
}
os_configure(){
	#OS优化
	#####################################################################
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
	#####################################################################
    # 网络优化配置
    sudo tee /etc/sysctl.d/99-network-performance.conf > /dev/null << 'EOF'
# 网络队列和缓冲区优化
net.core.netdev_max_backlog = 250000
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.core.optmem_max = 16777216
net.core.somaxconn = 65535

# TCP优化
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_max_syn_backlog = 30000
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_window_scaling = 1

# 使用BBR拥塞控制算法（如果内核支持）
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# 增加本地端口范围
net.ipv4.ip_local_port_range = 1024 65535

# 软中断和网络处理优化
net.core.netdev_budget = 600
net.core.netdev_budget_usecs = 10000
net.core.dev_weight = 600

# 连接跟踪优化
net.netfilter.nf_conntrack_max = 2097152
net.netfilter.nf_conntrack_tcp_timeout_established = 86400
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30

# 禁用IPv6（如果不需要）
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

# 内存管理优化
vm.swappiness = 10
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.min_free_kbytes = 1048576
vm.zone_reclaim_mode = 0
vm.max_map_count = 1048576

# 文件系统和I/O优化
fs.file-max = 20000000
fs.nr_open = 20000000
fs.aio-max-nr = 1048576
fs.inotify.max_user_watches = 524288
EOF
    sudo sysctl -p /etc/sysctl.d/99-network-performance.conf
	#####################################################################
    # 中断亲和性设置    
    systemctl stop irqbalance
    IFACE=$(ip route | grep default | awk '{print $5}')
    irqs=$(grep "${IFACE}-Tx-Rx" /proc/interrupts | awk -F':' '{print $1}')
    cpu=0
    for i in $irqs; do
      echo $cpu > /proc/irq/$i/smp_affinity_list
      let cpu=${cpu}+1
    done
    #####################################################################
    # 其他
    cat >> /etc/security/limits.conf << EOF
# 如果使用 root 或其他用户运行
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

PKGCMD=dnf
PKGCMD1=dnf
NGINX_PKG_NAME="nginx"
# NGINX conf
NGINX_SERVICE="nginx"
NGINX_CONF="/etc/nginx/nginx.conf"

install_public_tools
os_configure
install_nginx
modify_nginxcnf
