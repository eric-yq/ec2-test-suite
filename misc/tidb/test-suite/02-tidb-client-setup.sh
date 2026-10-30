#!/bin/bash 

#################################################################################################################
# TiDB TPC-H 测试脚本 , 在一台 tidb-client 实例上执行.
# 该实例和 tidb-node 在同一个 subnet 和 安全组，同时加入 default 安全组
# vpc-00dff4c509ba673b8
# subnet-0691c2ea78520c3f7
# sg-0cb2fd382e1534e25
# sg-0a5a40cef0d729653
# 这个实例在启动之后，没有公网 IP 地址，通过控制台连接。
#################################################################################################################
# 安装基础软件包
yum update -yq
yum install -yq python3-pip htop
pip3 install dool
rpm -Uvh https://repo.mysql.com/mysql80-community-release-el9.rpm
yum install -yq mysql

# 测试 mysql 客户端远程访问
cat >> ~/.bash_profile << EOF
export tidb_host="acbb9153ddd0b4915b8ec30ee2c46f47-0e3f4c123ad209df.elb.us-east-2.amazonaws.com"
export sf=300
export wares=1000
EOF
source ~/.bash_profile
mysql -h ${tidb_host} -P 4000 -u root -e "show databases;"

# 安装 TiUP
cd /root/
curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh
source /root/.bash_profile
tiup install playground
tiup install bench
