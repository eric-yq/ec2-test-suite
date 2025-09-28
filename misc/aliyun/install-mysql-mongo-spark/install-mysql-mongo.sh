#!/bin/bash

###################################################################################
# 1. 首先，在香港区域，使用 ECS 配置：r9i.2xlarge 实例，
#    采用 ESSD PL1，1000GB，吞吐为 min{120+0.5*容量, 750}=620MB/s
# 2. 安装/配置 MySQL, MongoDB，Spark 等软件
#    做镜像，然后复制到 杭州区域。
# PS：在 AWS region，按照 ESSD PL1 的容量 1000GB，吞吐 620MB/s, 16000 IOPS（gp3上限），重新测试 MySQL, Mongo 和 Spark。

###################################################################################



###################################################################################
# MYSQL
SUT_NAME="mysql"
echo "$0: Install SUT_NAME: ${SUT_NAME}"

## 获取OS 、CPU 架构信息。
PKGCMD=dnf
PKGCMD1=dnf
MYSQL_REPO="mysql80-community-release-el8.rpm"

# mysql conf
MYSQL_SERVICE="mysqld"
MYSQL_CONF="/etc/my.cnf"

# 修改初始密码，
cat << EOF > create_remote_login_user.sql
alter user 'root'@'localhost' identified with mysql_native_password by 'DoNotChangeMe@@123';
set global validate_password.policy=0;
alter user 'root'@'localhost' identified with mysql_native_password by 'gv2mysql';
create user 'root'@'%' identified with mysql_native_password by 'gv2mysql';
grant all privileges on *.* to 'root'@'%' with grant option;
flush privileges;
EOF

# ## functions
# install_public_tools(){
$PKGCMD update -y
$PKGCMD install -y dmidecode net-tools htop git python3-pip
pip3 install dool

# install_mysql(){
wget https://repo.mysql.com//${MYSQL_REPO}
rpm -Uvh ${MYSQL_REPO}
$PKGCMD remove  -y mariadb-devel
$PKGCMD install -y mysql-server --nogpgcheck
$PKGCMD install -y mysql-devel --nogpgcheck
$PKGCMD install -y mysql --nogpgcheck

# modify_mycnf(){
## 修改配置文件
cp ${MYSQL_CONF} ${MYSQL_CONF}.bak

## 获取 CPU数 和 内存数量（MB）
CPU_CORES=$(nproc)
MEM_TOTAL_MB=$(free -m |grep Mem | awk -F " " '{print $2}')

## 变量计算
let XXX=${MEM_TOTAL_MB}*75/100

mkdir -p /data/
cat << EOF > ${MYSQL_CONF}
[mysqld]
server-id=123
datadir=/data/
log-bin=/data/mysql-bin
socket=/var/lib/mysql/mysql.sock
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid

######################################################
## yuanquan : performance related configrations
## if on EBS: suggest disable them all;
## if on instance store: suggest enable them all;
performance_schema=off
skip_log_bin=1
innodb_flush_log_at_trx_commit=0
binlog_expire_logs_seconds=3600
######################################################
# general
max_connections=4000
table_open_cache=8000
table_open_cache_instances=16
back_log=1500
default_password_lifetime=0
ssl=0
max_prepared_stmt_count=128000
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
# 20240815-new-added
innodb_use_fdatasync=ON
EOF

systemctl restart ${MYSQL_SERVICE}
systemctl status  ${MYSQL_SERVICE}

# init_start_mysql()
MYSQL_INIT_PASSWORD=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}')
if [[ x${MYSQL_INIT_PASSWORD} == x ]]; then
    MYSQL_CMD_OPTIONS=""
else 
    MYSQL_CMD_OPTIONS="--connect-expired-password -uroot -p${MYSQL_INIT_PASSWORD}"
fi
## 修改初始密码
cat create_remote_login_user.sql
mysql ${MYSQL_CMD_OPTIONS} < create_remote_login_user.sql



###################################################################################
# MONGODB
SUT_NAME="mongo"
echo "$0: Install SUT_NAME: ${SUT_NAME}"

## 获取OS 、CPU 架构信息。
OS_NAME=$(egrep ^NAME /etc/os-release | awk -F "\"" '{print $2}')
OS_VERSION=$(egrep ^VERSION_ID /etc/os-release | awk -F "\"" '{print $2}')
ARCH=$(lscpu | grep Architecture | awk -F " " '{print $NF}')

## 添加 MongoDB Repo
MONGO_XY="8.0"
cat << EOF > /etc/yum.repos.d/mongodb-org-${MONGO_XY}-${ARCH}.repo
[mongodb-org-${MONGO_XY}-${ARCH}]
name=MongoDB Repository for ${MONGO_XY}-${ARCH}
baseurl=https://repo.mongodb.org/yum/redhat/8/mongodb-org/${MONGO_XY}/${ARCH}/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-${MONGO_XY}.asc
EOF

# mongo conf
MONGO_SERVICE="mongod"
MONGO_CONF="/etc/mongod.conf"

## install_public_tools
yum install -y dmidecode
yum install -y epel
yum install -y dmidecode net-tools htop git python3-pip
pip3 install dool

## OS CONFIG
sysctl -w vm.max_map_count=98000
sysctl -w kernel.pid_max=64000
sysctl -w kernel.threads-max=64000
sysctl -w vm.max_map_count=128000
sysctl -w net.core.somaxconn=65535

# install_mongo
yum install -y mongodb-mongosh-shared-openssl3
yum install -y mongodb-org
MONGO_USER_GROUP=$(grep mongo /etc/passwd | awk -F ":" '{print $1}')

mkdir -p /data/mongodb
chown -R ${MONGO_USER_GROUP}:${MONGO_USER_GROUP} /data/mongodb
cp ${MONGO_CONF} ${MONGO_CONF}.bak

## 设置 cacheSizeGB
MEM_TOTAL_GB=$(free -g |grep Mem | awk -F " " '{print $2}')
let XXX=${MEM_TOTAL_GB}*80/100

cat << EOF > ${MONGO_CONF}
systemLog:
destination: file
logAppend: true
path: /var/log/mongodb/mongod.log

processManagement:
timeZoneInfo: /usr/share/zoneinfo

net:
port: 27017
bindIpAll: true
maxIncomingConnections: 65535

operationProfiling:
mode: off

storage:
dbPath: /data/mongodb
directoryPerDB: true
engine: wiredTiger
wiredTiger:
engineConfig:
    cacheSizeGB: ${XXX}
    directoryForIndexes: true
    journalCompressor: snappy
collectionConfig:
    blockCompressor: snappy
indexConfig:
    prefixCompression: true

EOF

systemctl restart ${MONGO_SERVICE}
systemctl status ${MONGO_SERVICE}
sleep 5

# init_start_mongo
## 创建 root 用户
mongosh << EOF
use admin
db.createUser({user:'root',pwd:'gv2mongo',roles:['root']});
exit
EOF
echo "security:" >> ${MONGO_CONF}
echo "  authorization: enabled" >> ${MONGO_CONF}

systemctl restart ${MONGO_SERVICE}
systemctl status ${MONGO_SERVICE}

wget --quiet https://atlas-education.s3.amazonaws.com/sampledata.archive
mongorestore --archive=sampledata.archive --username root --password gv2mongo

###################################################################################