#!/bin/bash
# Amazon Linux 2023, r8i.4xlarge
# EBS: 200G gp3, 性能 10000 IOPS, 500 MB/s
sudo su - root

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

# root密码
echo "export ROOT_PASSWORD=gv2mysql" >> ~/.bash_profile
source ~/.bash_profile

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
# obclient -h127.0.0.1 -P2881 -uroot@sys -p'dBdlaKRchufYZBxBiS9x' -Doceanbase -A

# obd cluster stop   obtest        
# obd cluster reload obtest   
# obd cluster start  obtest

##########################################################################################
# TPCH 参考：https://www.oceanbase.com/docs/common-oceanbase-cloud-1000000001713939
# 数据库配置
obclient -h127.0.0.1 -P2881 -uroot@sys -p'dBdlaKRchufYZBxBiS9x' -Doceanbase -A
# 执行...
# obclient(root@sys)[oceanbase]> 
SET GLOBAL ob_sql_work_area_percentage = 80;
SET GLOBAL ob_query_timeout = 36000000000;
SET GLOBAL ob_trx_timeout = 36000000000;
SET GLOBAL max_allowed_packet = 67108864;
SET GLOBAL parallel_servers_target = 624;

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
# added for oceanbase tpch test
#ifdef MYSQL
#define GEN_QUERY_PLAN ""
#define START_TRAN "START TRANSACTION"
#define END_TRAN "COMMIT"
#define SET_OUTPUT ""
#define SET_ROWCOUNT "limit %d;\n"
#define SET_DBASE "use %s;\n"
#endif
EOF

yum group install -y "Development Tools"

make