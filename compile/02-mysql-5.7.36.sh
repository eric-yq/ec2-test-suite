#!/bin/bash

## 实例名称： AB23-Demo-MySQL5.7.36-编译-AL2
## 实例规格： m7g.2xlarge
## 编译时间： 7 分钟
## 在 /varlog/cloud-init-out.log 查看执行过程

cd /root/

## 安装 cmake
ARCH=$(lscpu | grep Architecture | awk -F " " '{print $NF}')   ## aarch64, x86_64
mkdir /root/cmake-3.25.2-linux-${ARCH}
cd /root/cmake-3.25.2-linux-${ARCH}
wget -q https://github.com/Kitware/CMake/releases/download/v3.25.2/cmake-3.25.2-linux-${ARCH}.sh
sh cmake-3.25.2-linux-${ARCH}.sh --skip-license 
ln -s /root/cmake-3.25.2-linux-${ARCH}/bin/cmake /usr/bin/cmake
cmake -version

## 安装开发工具、监控工具
yum update -y 
amazon-linux-extras install -y epel
yum groupinstall -y development
yum install -y gcc10 gcc10-c++
yum install -y dstat htop nload iotop mytop 
yum install -y ncurses ncurses-devel bison openssl-devel

## 设置使用 GCC 10.4 版本
mv /usr/bin/gcc /usr/bin/gcc7.3
mv /usr/bin/g++ /usr/bin/g++7.3
alternatives --install /usr/bin/gcc gcc /usr/bin/gcc10-cc  100
alternatives --install /usr/bin/g++ g++ /usr/bin/gcc10-c++ 100
gcc --version
g++ --version

## Enable Transparent Huge Pages (THP) 
echo always > /sys/kernel/mm/transparent_hugepage/enabled

## 安装 boost
cd ~
wget -q http://sourceforge.net/projects/boost/files/boost/1.59.0/boost_1_59_0.tar.gz
tar zxf boost_1_59_0.tar.gz -C /usr/local/

## 下载 MySQL 代码, 从 https://github.com/mysql/mysql-server/tags 查找。
cd ~
wget -q https://github.com/mysql/mysql-server/archive/refs/tags/mysql-5.7.36.tar.gz
tar zxf mysql-5.7.36.tar.gz

## 创建用户和目录
groupadd -r mysql
useradd  -r -g mysql -s /sbin/nologin -M mysql
mkdir -p /database/mysql/{data,tmp,binlog,logs}

## 预编译 #######################################################################
#screen -R ttt
cd /root/mysql-server-mysql-5.7.36
cmake . \
-DCMAKE_INSTALL_PREFIX=/database/mysql \
-DMYSQL_DATADIR=/database/mysql/data \
-DMYSQL_UNIX_ADDR=/database/mysql/tmp/mysql.sock \
-DSYSCONFDIR=/etc \
-DWITH_ARCHIVE_STORAGE_ENGINE=1 \
-DWITH_BLACKHOLE_STORAGE_ENGINE=1 \
-DWITH_INNOBASE_STORAGE_ENGINE=1 \
-DWITH_PERFSCHEMA_STORAGE_ENGINE=1 \
-DWITH_BOOST=/usr/local/boost_1_59_0 \
-DDEFAULT_CHARSET=utf8 \
-DDEFAULT_COLLATION=utf8_general_ci \
-DWITH_EXTRA_CHARSETS=all \
-DWITH_SSL=system \
-DCMAKE_C_FLAGS="-O3 -mcpu=neoverse-n1 -fsigned-char" \
-DCMAKE_CXX_FLAGS="-O3 -mcpu=neoverse-n1"
################################################################################

## 编译和安装
make -j $(nproc)
make install
ll /database/mysql/bin
cd ~

## 生成配置文件
echo 'export PATH=/database/mysql/bin:$PATH' >> /etc/profile
source /etc/profile
chown -R mysql:mysql /database/mysql/
chown mysql:mysql /etc/my.cnf
cp /etc/my.cnf /etc/my.cnf.bak

cat << EOF > /etc/my.cnf
[client]
port = 3306 
socket = /database/mysql/tmp/mysql.sock
default-character-set = utf8
[mysqld]
port = 3306
server_id = 1
user = mysql
character_set_server = utf8
max_connections = 1024
max_connect_errors = 10
basedir = /database/mysql
datadir = /database/mysql/data
tmpdir = /database/mysql/tmp
socket = /database/mysql/tmp/mysql.sock
pid_file = /database/mysql/mysql.pid
log_error = /database/mysql/logs/mysql_5_7_37.err
log_bin = /database/mysql/binlog/mysql-bin
skip-log-bin
EOF

## 初始化 MySQL
cd /database/mysql
./bin/mysqld --initialize-insecure --user=mysql \
 --basedir=/database/mysql --datadir=/database/mysql/data
 
./bin/mysql_ssl_rsa_setup --initialize-insecure --user=mysql \
 --basedir=/database/mysql --datadir=/database/mysql/data
chmod +r /database/mysql/data/server-key.pem

## 配置服务启动
ln -s /database/mysql/support-files/mysql.server /etc/init.d/mysqld
systemctl daemon-reload
/sbin/chkconfig mysqld on

## 启动 MySQL 服务
/etc/init.d/mysqld start
/etc/init.d/mysqld status

## 创建用于远程登录时的 root 用户、密码和权限。下面用于 MySQL 5.7.z 版本。
cd ~
cat << EOF > create_remote_login_user.sql
alter user 'root'@'localhost' identified with mysql_native_password by 'DoNotChangeMe@@123';
alter user 'root'@'localhost' identified with mysql_native_password by 'gv2mysql';
create user 'root'@'%' identified with mysql_native_password by 'gv2mysql';
grant all privileges on *.* to 'root'@'%' with grant option;
flush privileges;
EOF
mysql < create_remote_login_user.sql