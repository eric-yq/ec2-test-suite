#!/bin/bash
# Amazon Linux 2023, r8i.4xlarge
# EBS: 200G gp3, 性能 10000 IOPS, 500 MB/s
sudo su - root
git clone https://github.com/eric-yq/ec2-test-suite.git

# 修改系统限制
cat << EOF >> /etc/security/limits.conf
* soft nofile 655350
* hard nofile 655350
* soft stack unlimited
* hard stack unlimited
* soft nproc 655350
* hard nproc 655350
* soft core unlimited
* hard core unlimited
EOF

# 修改内核参数
cat << EOF >> /etc/sysctl.conf
fs.aio-max-nr=1048576
net.core.somaxconn=2048
net.core.netdev_max_backlog=10000
net.core.rmem_default=16777216
net.core.wmem_default=16777216
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.ip_local_port_range=3500 65535
net.ipv4.ip_forward=0
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.default.accept_source_route=0
net.ipv4.tcp_syncookies=0
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.ipv4.tcp_max_syn_backlog=16384
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_max_tw_buckets=262144
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_syn_retries=3
net.ipv4.tcp_synack_retries=3
vm.max_map_count=655350
EOF
# 应用系统参数
sysctl -p

## 重新登录 session
logout
sudo su - root

# root密码
# echo "export ROOT_PASSWORD=gv2mysql" >> ~/.bash_profile
# source ~/.bash_profile

# 准备 all-in-one 版本
bash -c "$(curl -s https://obbusiness-private.oss-cn-shanghai.aliyuncs.com/download-center/opensource/oceanbase-all-in-one/installer.sh)"
source ~/.oceanbase-all-in-one/bin/env.sh

# 部署集群: 最大规格部署
# obd 自 V3.4.0 起提供最大规格部署命令，执行后将以 OceanBase 数据库最大规格部署并启动单节点的 OceanBase 数据库及相关组件。
obd pref

# +---------------------------------------------+
# |                 oceanbase-ce                |
# +-----------+---------+------+-------+--------+
# | ip        | version | port | zone  | status |
# +-----------+---------+------+-------+--------+
# | 127.0.0.1 | 4.4.1.0 | 2881 | zone1 | ACTIVE |
# +-----------+---------+------+-------+--------+
# x86 
# obclient -h127.0.0.1 -P2883 -uroot@sys -p'GH7GM1wVfjUiMSmrpyFy' -Doceanbase -A 
# arm
# obclient -h127.0.0.1 -P2881 -uroot@sys -p'Khlwmj5BnkwsToKDNLTw' -Doceanbase -A

# obd cluster stop   obtest        
# obd cluster reload obtest   
# obd cluster start  obtest

##########################################################################################
# TPCH 参考：https://www.oceanbase.com/docs/common-oceanbase-cloud-1000000001713939
# 数据库配置
obclient -h127.0.0.1 -P2883 -uroot@sys -p'GH7GM1wVfjUiMSmrpyFy' -Doceanbase -A 
# 执行...
# obclient(root@sys)[oceanbase]> 
SET GLOBAL ob_sql_work_area_percentage = 80;
SET GLOBAL ob_query_timeout = 36000000000;
SET GLOBAL ob_trx_timeout = 36000000000;
SET GLOBAL max_allowed_packet = 67108864;
SET GLOBAL parallel_servers_target = 624;
# obclient(root@sys)[oceanbase]> exit
# Bye

# 上传 并解压TPCH 安装包
unzip -q 5D69EC5B-533B-4DF1-B544-E3BD4BBE265F-TPC-H-Tool.zip

# 准备 TPC-H 测试工具
cd TPC-H_Tools_v3.0.0/dbgen/
cp makefile.suite Makefile
# 修改Makefile文件中的CC、DATABASE、MACHINE、WORKLOAD等参数定义。
sed -i "s/CC      = /CC      = gcc/g" Makefile
sed -i "s/DATABASE= /DATABASE= MYSQL/g" Makefile
sed -i "s/MACHINE = /MACHINE = LINUX/g" Makefile
sed -i "s/WORKLOAD = /WORKLOAD = TPCH/g" Makefile

# 修改 tpcd.h 头文件
cat << EOF >> tpcd.h
#ifdef MYSQL
#define GEN_QUERY_PLAN ""
#define START_TRAN "START TRANSACTION"
#define END_TRAN "COMMIT"
#define SET_OUTPUT ""
#define SET_ROWCOUNT "limit %d;\n"
#define SET_DBASE "use %s;\n"
#endif
EOF

# 构建数据生成工具
yum group install -yq "Development Tools"
yum install -yq python3-pip htop
pip3 install dool
make

# 生成数据,例如生成 50GB 的数据：
SF=50
./dbgen -s $SF
mkdir tpch$SF
mv *.tbl tpch$SF

# 修改查询任务的 SQL 文件
cp -r queries queries_bak
cp -r /usr/obd/plugins/tpch/3.1.0/queries/ .
sed -i "s/cpu_num/$(nproc)/g" queries/*.sql

# 修改创建表的 SQL 文件
mkdir -p load
cd load
cp -r /usr/obd/plugins/tpch/3.1.0/create_tpch_mysql_table_part.ddl .
sed -i "s/cpu_num/$(nproc)/g" create_tpch_mysql_table_part.ddl
## 将 create_table.py 和 load.py 下载到当前目录，并根据实际情况修改其中的参数
cp /root/ec2-test-suite/misc/oceanbase/tpch/create_table.py .
cp /root/ec2-test-suite/misc/oceanbase/tpch/load.py .

# 创建表并加载数据
screen -R ttt -L
python3 create_table.py
python3 load.py

# 通过 dool 查看

# 执行合并操作
obclient -h127.0.0.1 -P2881 -uroot@sys -p'Khlwmj5BnkwsToKDNLTw' -Doceanbase -A -e \
  "ALTER SYSTEM major freeze;"
# Query OK, 0 rows affected (0.011 sec)

## 查看状态
obclient -h127.0.0.1 -P2881 -uroot@sys -p'Khlwmj5BnkwsToKDNLTw' -Doceanbase -A -e \
  "select STATUS from oceanbase.DBA_OB_MAJOR_COMPACTION;"
# +------------+
# | STATUS     |
# +------------+
# | COMPACTING |
# +------------+
# 1 row in set (0.001 sec)

## 直到完成
obclient -h127.0.0.1 -P2881 -uroot@sys -p'Khlwmj5BnkwsToKDNLTw' -Doceanbase -A -e \
  "select STATUS from oceanbase.DBA_OB_MAJOR_COMPACTION;"
# +--------+
# | STATUS |
# +--------+
# | IDLE   |
# +--------+
# 1 row in set (0.001 sec)

## 收集统计信息
obclient -h127.0.0.1 -P2881 -uroot@sys -p'Khlwmj5BnkwsToKDNLTw' -Doceanbase -A -e \
  "call dbms_stats.gather_schema_stats('oceanbase',degree=>96);"
# Query OK, 0 rows affected (3 min 46.688 sec)

## 执行查询
cd /root/TPC-H_Tools_v3.0.0/dbgen/queries
cp /root/ec2-test-suite/misc/oceanbase/tpch/tpch.sh .
chmod +x tpch.sh
bash tpch.sh

