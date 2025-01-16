#!/bin/bash

SUT_NAME=${1}
echo "$0: Install SUT_NAME: ${SUT_NAME}"

install_public_tools(){
	$PKGCMD update -y
	$PKGCMD1 install -y epel
	$PKGCMD install -y dmidecode net-tools dstat htop nload
# 	$PKGCMD install -y stress-ng
# 	$PKGCMD install -y perf
	$PKGCMD install -y git
}
install_mysql(){
    wget https://repo.mysql.com//${MYSQL_REPO}
    rpm -Uvh ${MYSQL_REPO}
    $PKGCMD install -y mysql-server
    $PKGCMD install -y mysql-devel
    $PKGCMD install -y mysql
    systemctl start  ${MYSQL_SERVICE}
	systemctl status ${MYSQL_SERVICE}
}
init_start_mysql(){
	MYSQL_INIT_PASSWORD=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}')
	if [[ x${MYSQL_INIT_PASSWORD} == x ]]; then
        MYSQL_CMD_OPTIONS=""
    else 
        MYSQL_CMD_OPTIONS="--connect-expired-password -uroot -p${MYSQL_INIT_PASSWORD}"
    fi
    ## 修改初始密码
    cat create_remote_login_user.sql
	mysql ${MYSQL_CMD_OPTIONS} < create_remote_login_user.sql
}
modify_mycnf(){
	## 修改配置文件
    cp ${MYSQL_CONF} ${MYSQL_CONF}.bak
    IPADDR=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | awk -F " " '{print $2}')
    sed -i "s/127.0.0.1/${IPADDR}/g" ${MYSQL_CONF}
    
	## 获取 CPU数 和 内存数量（MB）
	CPU_CORES=$(nproc)
	MEM_TOTAL_MB=$(free -m |grep Mem | awk -F " " '{print $2}')

	## 变量计算
	let XXX=${MEM_TOTAL_MB}*75/100

    cat << EOF >> ${MYSQL_CONF}
# general
max_connections=4000
table_open_cache=8000
table_open_cache_instances=16
back_log=1500
default_password_lifetime=0
ssl=0
performance_schema=OFF
max_prepared_stmt_count=128000
skip_log_bin=1
character_set_server=latin1
collation_server=latin1_swedish_ci
transaction_isolation=REPEATABLE-READ
# files
innodb_file_per_table
innodb_log_file_size=1024M
innodb_log_files_in_group=16
innodb_open_files=4000
# buffers
innodb_buffer_pool_size=${XXX}M
innodb_buffer_pool_instances=16	
innodb_log_buffer_size=64M
# tune
# innodb_page_size=8192
innodb_doublewrite=0
innodb_thread_concurrency=0
innodb_flush_log_at_trx_commit=0
innodb_max_dirty_pages_pct=90
innodb_max_dirty_pages_pct_lwm=10
join_buffer_size=32K
sort_buffer_size=32K
innodb_use_native_aio=1
innodb_stats_persistent=1
innodb_spin_wait_delay=6
innodb_max_purge_lag_delay=300000
innodb_max_purge_lag=0
innodb_flush_method=O_DIRECT_NO_FSYNC
innodb_checksum_algorithm=none
innodb_io_capacity=4000
innodb_io_capacity_max=20000
innodb_lru_scan_depth=9000
innodb_change_buffering=none
innodb_read_only=0
innodb_page_cleaners=4
innodb_undo_log_truncate=off
# perf special
innodb_adaptive_flushing=1
innodb_flush_neighbors=0
innodb_read_io_threads=16
innodb_write_io_threads=16
innodb_purge_threads=4
innodb_adaptive_hash_index=0
EOF

	## 设置 GTID 方式的主从复制	
	cat << EOF >> ${MYSQL_CONF}
server-id=$(echo $RANDOM)
binlog_format = row
gtid-mode = on
enforce-gtid-consistency = true
log-slave-updates = 1
sync-master-info = 1
master-info-repository = TABLE
relay-log-info-repository = TABLE
slave-parallel-workers = $(nproc)
EOF
    
    systemctl restart ${MYSQL_SERVICE}
	systemctl status  ${MYSQL_SERVICE}
}

# 主要流程

## 获取OS 、CPU 架构信息。
OS_NAME=$(egrep ^NAME /etc/os-release | awk -F "\"" '{print $2}')
# OS_ID=$(egrep "^ID=" /etc/os-release | awk -F "\"" '{print $2}') 
OS_VERSION=$(egrep ^VERSION_ID /etc/os-release | awk -F "\"" '{print $2}') 
ARCH=$(lscpu | grep Architecture | awk -F " " '{print $NF}') 
PN=$(dmidecode -s system-product-name | tr ' ' '_')

if   [[ "$OS_NAME" == "Amazon Linux" ]]; then
	if   [[ "$OS_VERSION" == "2" ]]; then
		PKGCMD=yum
		PKGCMD1=amazon-linux-extras
		MYSQL_REPO="mysql80-community-release-el7-7.noarch.rpm"
	elif [[ "$OS_VERSION" == "2023" ]]; then
		PKGCMD=dnf
		PKGCMD1=dnf
		MYSQL_REPO="mysql80-community-release-el9.rpm"
	else
		echo "$0: $OS_NAME $OS_VERSION not supported"
		exit 1
	fi
		
	# mysql conf
	MYSQL_SERVICE="mysqld"
	MYSQL_CONF="/etc/my.cnf"

	# 修改初始密码
	cat << EOF > create_remote_login_user.sql
alter user 'root'@'localhost' identified with mysql_native_password by 'DoNotChangeMe@@123';
set global validate_password.policy=0;
alter user 'root'@'localhost' identified with mysql_native_password by 'gv2mysql';
create user 'root'@'%' identified with mysql_native_password by 'gv2mysql';
grant all privileges on *.* to 'root'@'%' with grant option;
flush privileges;
EOF

elif [[ "$OS_NAME" == "Ubuntu" ]]; then
	PKGCMD=apt
	PKGCMD1=apt
		
	# mysql conf
	MYSQL_SERVICE="mysql"
	MYSQL_CONF="/etc/mysql/mysql.conf.d/mysqld.cnf"
	
	# 修改初始密码
	cat << EOF > create_remote_login_user.sql
alter user 'root'@'localhost' identified with mysql_native_password by 'gv2mysql';
create user 'root'@'%' identified with mysql_native_password by 'gv2mysql';
grant all privileges on *.* to 'root'@'%' with grant option;
flush privileges;
EOF
	
# elif [[ "$OS_NAME" == "CentOS Linux" ]] && [[ "$OS_VERSION" == "7" ]]; then
# 	install_centos7_dependencies
# 
# elif [[ "$OS_NAME" == "CentOS Stream" ]] && [[ "$OS_VERSION" == "8" ]]; then
# 	install_centos8_dependencies
# 
# elif [[ "$OS_NAME" == "CentOS Stream" ]] && [[ "$OS_VERSION" == "9" ]]; then
# 	install_centos9_dependencies

else
	echo "$0: $OS_NAME not supported"
	exit 1
fi

# mysql installation
install_public_tools
install_mysql
init_start_mysql
modify_mycnf
	

