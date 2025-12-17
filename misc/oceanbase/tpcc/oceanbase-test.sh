#!/bin/bash
# Ubuntu 22.04
# EBS: 100G gp3, 性能 5000 IOPS, 500 MB/s
sudo su - root

# 修改系统限制
cat << EOF | sudo tee -a /etc/security/limits.conf
* soft nofile 655350
* hard nofile 655350
* soft stack 20480
* hard stack 20480
* soft nproc 655350
* hard nproc 655350
* soft core unlimited
* hard core unlimited
EOF
# 修改内核参数
cat << EOF | sudo tee -a /etc/sysctl.conf
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

# 准备部署集群的配置文件
CPU_CORES=$(nproc)
let YYY=${CPU_CORES}-2
let ZZZ=${CPU_CORES}*10/80
cat << EOF > ~/oceanbase.yaml
oceanbase-ce:
  servers:
    - 127.0.0.1
  global:
    home_path: /root/observer
    data_dir: /mnt/data
    redo_dir: /mnt/redo
    mysql_port: 2881
    rpc_port: 2882
    zone: zone1
    cluster_id: 1
    deploy_mode: standalone
    production_mode: false
    root_password: gv2mysql
    # CPU 
    cpu_count: ${YYY}
    # Memory
    memory_limit_percentage: 80
    system_memory: 2G
    # Network
    net_thread_count: ${ZZZ}
    # Disk usage
    datafile_disk_percentage: 70
    datafile_next: 2G
    datafile_maxsize: 20G
    log_disk_percentage: 10
    syslog_level: INFO
    enable_syslog_wf: false
    enable_syslog_recycle: true
    max_syslog_file_count: 10
EOF

# 部署集群
obd cluster deploy obtest -c ~/oceanbase.yaml
obd cluster start obtest

# obd cluster stop   obtest        
# obd cluster reload obtest   
# obd cluster start  obtest

##########################################################################################
# 安装 BenchmarkSQL 工具
apt install -y openjdk-17-jdk unzip net-tools python3-pip net-tools htop iotop ant
pip3 install dool
wget https://github.com/eric-yq/ec2-test-suite/raw/refs/heads/main/misc/oceanbase/benchmarksql-5.0_for_oceanbase_tpcc.tar.gz
tar zxf benchmarksql-5.0_for_oceanbase_tpcc.tar.gz
cd benchmarksql-5.0
ant

# 下载jdbc mysql驱动文件
cd /root/
wget https://downloads.mysql.com/archives/get/p/3/file/mysql-connector-java-5.1.47.tar.gz
tar zxf mysql-connector-java-5.1.47.tar.gz
mv mysql-connector-java-5.1.47/*.jar benchmarksql-5.0/lib/

# 创建 tpcc 测试的配置文件
let DURATION=720
let WAREHOUSE=500
CPU_CORES=$(nproc)
let TERMINALS=${CPU_CORES}*10/10
cat > ~/benchmarksql-5.0/run/props.ob  << EOF
db=oceanbase
driver=com.mysql.jdbc.Driver
conn=jdbc:mysql://127.0.0.1:2881/tpccdb?useUnicode=true&characterEncoding=utf-8&rewriteBatchedStatements=true&allowMultiQueries=true
user=root@test
password=gv2mysql

warehouses=${WAREHOUSE}
loadWorkers=8
terminals=${TERMINALS}

//To run specified transactions per terminal- runMins must equal zero
runTxnsPerTerminal=0
//To run for specified minutes- runTxnsPerTerminal must equal zero
runMins=${DURATION}
//Number of total transactions per minute
limitTxnsPerMin=0

//Set to true to run in 4.x compatible mode. Set to false to use the
//entire configured database evenly.
terminalWarehouseFixed=true

//The following five values must add up to 100
newOrderWeight=55
paymentWeight=33
orderStatusWeight=4
deliveryWeight=4
stockLevelWeight=4

// Directory name to create for collecting detailed result data.
// Comment this out to suppress.
resultDirectory=my_result_%tY-%tm-%td_%tH%tM%tS
// osCollectorScript=./misc/os_collector_linux.py
// osCollectorInterval=1
EOF

##########################################################################################
# 准备数据库测试环境
# 创建 test 租户
# 首先查看剩余资源
ROOT_PASSWORD=${ROOT_PASSWORD}
MEM_FREE_GB=$(obclient -h127.0.0.1 -P2881 -uroot -p${ROOT_PASSWORD} -D oceanbase -A -N -s -e \
  "SELECT 
    round((mem_capacity - mem_assigned)/1024/1024/1024, 0) AS mem_free_gb 
   FROM oceanbase.gv\$ob_servers 
   WHERE zone = 'zone1';")
let YYY=${MEM_FREE_GB}-2
CPU_FREE_NUM=$(obclient -h127.0.0.1 -P2881 -uroot -p${ROOT_PASSWORD} -D oceanbase -A -N -s -e \
  "SELECT 
    (cpu_capacity_max - cpu_assigned_max) AS cpu_free_num 
  FROM oceanbase.gv\$ob_servers 
  WHERE zone = 'zone1';")
  
# 创建unit，pool和租户。根据上面查询到全部剩余资源，调整unit配置
obclient -h127.0.0.1 -P2881 -uroot@sys -p${ROOT_PASSWORD} -D oceanbase -A -N -s -e \
  "CREATE RESOURCE UNIT test 
     MAX_CPU=${CPU_FREE_NUM}, 
     MIN_CPU=${CPU_FREE_NUM}, 
     MEMORY_SIZE='${YYY}G',
     LOG_DISK_SIZE='5G';
    
    CREATE RESOURCE POOL test \
      UNIT='test', 
      UNIT_NUM=1, 
      ZONE_LIST=('zone1');
    
    CREATE TENANT test 
      charset='utf8mb4',
      replica_num=1, 
      zone_list=('zone1'),
      primary_zone='zone1',
      resource_pool_list=('test');"
    
# 为租户 test 的 root 用户创建密码
obclient -h127.0.0.1 -P2881 -uroot@test -e "ALTER USER root IDENTIFIED BY ${ROOT_PASSWORD};"

# 系统租户全局配置，关闭一些影响系统性能的选项
obclient -h127.0.0.1 -P2881 -uroot@sys -p${ROOT_PASSWORD} -D oceanbase -A -N -s -e \
  "alter system set enable_sql_audit=false;
   select sleep(5);
   alter system set enable_perf_event=false;
   alter system set syslog_level='ERROR';
   alter system set enable_record_trace_log=false;"

# 创建数据库
obclient -h127.0.0.1 -P2881 -uroot@test -p${ROOT_PASSWORD} -e "CREATE DATABASE tpccdb;"
# obclient -h127.0.0.1 -P2881 -uroot@test -p${ROOT_PASSWORD} -e "DROP DATABASE tpccdb;"

# 创建建表脚本，已经包含在压缩包benchmarksql-5.0_for_oceanbase_tpcc.tar.gz 
# vi ~/benchmarksql-5.0/run/sql.common/tableCreates_parts.sql
# #####
# create table bmsql_config (
# cfg_name    varchar(30) primary key,
# cfg_value   varchar(50)
# );
# -- drop tablegroup tpcc_group;
# create tablegroup tpcc_group binding true partition by hash partitions 9;
# create table bmsql_warehouse (
#    w_id        integer   not null,
#    w_ytd       decimal(12,2),
#    w_tax       decimal(4,4),
#    w_name      varchar(10),
#    w_street_1  varchar(20),
#    w_street_2  varchar(20),
#    w_city      varchar(20),
#    w_state     char(2),
#    w_zip       char(9),
#    primary key(w_id)
# )tablegroup='tpcc_group' partition by hash(w_id) partitions 9;
# create table bmsql_district (
#    d_w_id       integer       not null,
#    d_id         integer       not null,
#    d_ytd        decimal(12,2),
#    d_tax        decimal(4,4),
#    d_next_o_id  integer,
#    d_name       varchar(10),
#    d_street_1   varchar(20),
#    d_street_2   varchar(20),
#    d_city       varchar(20),
#    d_state      char(2),
#    d_zip        char(9),
#    PRIMARY KEY (d_w_id, d_id)
# )tablegroup='tpcc_group' partition by hash(d_w_id) partitions 9;
# create table bmsql_customer (
#    c_w_id         integer        not null,
#    c_d_id         integer        not null,
#    c_id           integer        not null,
#    c_discount     decimal(4,4),
#    c_credit       char(2),
#    c_last         varchar(16),
#    c_first        varchar(16),
#    c_credit_lim   decimal(12,2),
#    c_balance      decimal(12,2),
#    c_ytd_payment  decimal(12,2),
#    c_payment_cnt  integer,
#    c_delivery_cnt integer,
#    c_street_1     varchar(20),
#    c_street_2     varchar(20),
#    c_city         varchar(20),
#    c_state        char(2),
#    c_zip          char(9),
#    c_phone        char(16),
#    c_since        timestamp,
#    c_middle       char(2),
#    c_data         varchar(500),
#    PRIMARY KEY (c_w_id, c_d_id, c_id)
# )tablegroup='tpcc_group' partition by hash(c_w_id) partitions 9;
# create table bmsql_history (
#    hist_id  integer,
#    h_c_id   integer,
#    h_c_d_id integer,
#    h_c_w_id integer,
#    h_d_id   integer,
#    h_w_id   integer,
#    h_date   timestamp,
#    h_amount decimal(6,2),
#    h_data   varchar(24)
# )tablegroup='tpcc_group' partition by hash(h_w_id) partitions 9;
# create table bmsql_new_order (
#    no_w_id  integer   not null ,
#    no_d_id  integer   not null,
#    no_o_id  integer   not null,
#    PRIMARY KEY (no_w_id, no_d_id, no_o_id)
# )tablegroup='tpcc_group' partition by hash(no_w_id) partitions 9;
# create table bmsql_oorder (
#    o_w_id       integer      not null,
#    o_d_id       integer      not null,
#    o_id         integer      not null,
#    o_c_id       integer,
#    o_carrier_id integer,
#    o_ol_cnt     integer,
#    o_all_local  integer,
#    o_entry_d    timestamp,
#    PRIMARY KEY (o_w_id, o_d_id, o_id)
# )tablegroup='tpcc_group' partition by hash(o_w_id) partitions 9;
# create table bmsql_order_line (
#    ol_w_id         integer   not null,
#    ol_d_id         integer   not null,
#    ol_o_id         integer   not null,
#    ol_number       integer   not null,
#    ol_i_id         integer   not null,
#    ol_delivery_d   timestamp,
#    ol_amount       decimal(6,2),
#    ol_supply_w_id  integer,
#    ol_quantity     integer,
#    ol_dist_info    char(24),
#    PRIMARY KEY (ol_w_id, ol_d_id, ol_o_id, ol_number)
# )tablegroup='tpcc_group' partition by hash(ol_w_id) partitions 9;
# create table bmsql_item (
#    i_id     integer      not null,
#    i_name   varchar(24),
#    i_price  decimal(5,2),
#    i_data   varchar(50),
#    i_im_id  integer,
#    PRIMARY KEY (i_id)
# );
# create table bmsql_stock (
#    s_w_id       integer       not null,
#    s_i_id       integer       not null,
#    s_quantity   integer,
#    s_ytd        integer,
#    s_order_cnt  integer,
#    s_remote_cnt integer,
#    s_data       varchar(50),
#    s_dist_01    char(24),
#    s_dist_02    char(24),
#    s_dist_03    char(24),
#    s_dist_04    char(24),
#    s_dist_05    char(24),
#    s_dist_06    char(24),
#    s_dist_07    char(24),
#    s_dist_08    char(24),
#    s_dist_09    char(24),
#    s_dist_10    char(24),
#    PRIMARY KEY (s_w_id, s_i_id)
# )tablegroup='tpcc_group' use_bloom_filter=true partition by hash(s_w_id) partitions 9;
# #####

## 执行建表语句
cd ~/benchmarksql-5.0/run
./runSQL.sh props.ob sql.common/tableCreates_parts.sql
# obclient -h127.0.0.1 -P2881 -uroot@test -p${ROOT_PASSWORD} -D tpccdb -e "show tables;"

## 加载数据
obclient -h127.0.0.1 -P2881 -uroot@test -p${ROOT_PASSWORD} -D tpccdb -e \
  "SET GLOBAL ob_query_timeout = 3600000000;"
./runLoader.sh props.ob

## 补充创建两个索引
obclient -h127.0.0.1 -P2881 -uroot@test -p${ROOT_PASSWORD} -D tpccdb -e \
  "create index bmsql_customer_idx1 on  bmsql_customer (c_w_id, c_d_id, c_last, c_first) local;
  create  index bmsql_oorder_idx1 on  bmsql_oorder (o_w_id, o_d_id, o_carrier_id, o_id) local;"
  
## 查看租户test占用的磁盘空间
obclient -h127.0.0.1 -P2881 -uroot@sys -p${ROOT_PASSWORD} -D oceanbase -e \
	"select a.svr_ip,a.svr_port,a.tenant_id,b.tenant_name,
	  CAST(a.data_disk_in_use/1024/1024/1024 as DECIMAL(15,2)) data_disk_use_G,
	  CAST(a.log_disk_size/1024/1024/1024 as DECIMAL(15,2)) log_disk_size,
	  CAST(a.log_disk_in_use/1024/1024/1024 as DECIMAL(15,2)) log_disk_use_G
	 from __all_virtual_unit a,dba_ob_tenants b
	 where a.tenant_id=b.tenant_id;"

## (可选）对应租户做一次集群合并（major freeze）
obclient -h127.0.0.1 -P2881 -uroot@test -p${ROOT_PASSWORD} -D tpccdb -e \
    "ALTER SYSTEM MAJOR FREEZE;"

#直到STATUS都是IDLE
obclient -h127.0.0.1 -P2881 -uroot@sys -p${ROOT_PASSWORD} -D oceanbase -A -e  \
    "SELECT * FROM oceanbase.CDB_OB_ZONE_MAJOR_COMPACTION;"  

# 执行测试前性能调优，sys
obclient -h127.0.0.1 -P2881 -uroot@sys -p${ROOT_PASSWORD} -D oceanbase -A -N -s -e \
	"alter system set enable_perf_event=false;
	alter system set syslog_level='ERROR';
	alter system set enable_record_trace_log=false;
	##
	alter system set writing_throttling_trigger_percentage=100 tenant=test;
	alter system set writing_throttling_maximum_duration='1h';
	alter system set memstore_limit_percentage = 80; 
	alter system set freeze_trigger_percentage = 30; 
	alter system set large_query_threshold = '200s';
	alter system set cpu_quota_concurrency = 4;
	alter system set minor_compact_trigger=3;
	alter system set builtin_db_data_verify_cycle = 0;
	alter system set trace_log_slow_query_watermark = '10s';
	alter system set server_permanent_offline_time='36000s';
	alter system set _ob_get_gts_ahead_interval = '5ms';
	alter system set bf_cache_priority = 10;
	alter system set user_block_cache_priority=5;
	alter system set enable_sql_audit=false;
	alter system set enable_syslog_recycle='True';
	alter system set ob_enable_batched_multi_statement=true tenant=all;
	alter system set plan_cache_evict_interval = '30s';
	alter system set enable_monotonic_weak_read = false;"

## 执行测试
cd ~/benchmarksql-5.0/run
./runBenchmark.sh props.ob


##########################################################################################
## sysbench 测试
IPADDR="172.31.5.213"
# cleanup：
sysbench /root/sysbench-1.0.20/src/lua/oltp_read_write.lua --mysql-host=$IPADDR --mysql-port=2881 --mysql-db=testdb --mysql-user=root@test --mysql-password=gv2mysql --table_size=1000000 --tables=30 --rand-type=uniform --threads=32  --report-interval=10 --time=600 cleanup

# prepare：
sysbench oltp_read_write.lua --mysql-host=$IPADDR --mysql-port=2881 --mysql-db=testdb --mysql-user=root@test  --mysql-password=gv2mysql --table_size=1000000 --tables=30 --rand-type=uniform --threads=32  --report-interval=10 --time=600 prepare

##########################################################################################
## 安装 mysql 5.7 客户端
cd /root/
wget https://dev.mysql.com/get/mysql-apt-config_0.8.12-1_all.deb;
echo "mysql-apt-config mysql-apt-config/select-server select mysql-5.7" | sudo debconf-set-selections;
echo "mysql-apt-config mysql-apt-config/select-product select Ok" | sudo debconf-set-selections;
DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config_0.8.12-1_all.deb;
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B7B3B788A8D3785C;
echo "deb http://repo.mysql.com/apt/ubuntu bionic mysql-5.7" | sudo tee /etc/apt/sources.list.d/mysql.list;
apt update
apt install -y mysql-client=5.7*


mysql -h 127.0.0.1 -uroot -P2883 -p'UOY7x7evbn6rZcqCx010'
mysql> create database tpcc;
mysql> CREATE USER 'tpcc'@'%' IDENTIFIED BY '123456';
mysql> GRANT ALL ON tpcc.* TO 'tpcc'@'%';
mysql> exit

# 获取root@sys密码
# ROOT_PASSWORD=$(grep root_password ~/.obd/cluster/demo/config.yaml | awk -F " " '{print $NF}')

# wget https://jaist.dl.sourceforge.net/project/benchmarksql/benchmarksql-5.0.zip
# unzip benchmarksql-5.0.zip
### 参考下面文档进行适配：https://www.oceanbase.com/docs/common-oceanbase-database-cn-1000000002013258#6-title-%E9%80%82%E9%85%8D%20Benchmark%20SQL5

# Reference: https://www.oceanbase.com/docs/common-oceanbase-database-cn-1000000002013258
# ......
# +---------------------------------------------+
# |                 oceanbase-ce                |
# +-----------+---------+------+-------+--------+
# | ip        | version | port | zone  | status |
# +-----------+---------+------+-------+--------+
# | 127.0.0.1 | 4.3.5.0 | 2881 | zone1 | ACTIVE |
# +-----------+---------+------+-------+--------+
# obclient -h127.0.0.1 -P2881 -uroot -p'UOY7x7evbn6rZcqCx010' -D oceanbase -A
# 
# cluster unique id: 7a197725-7603-5cf8-bdef-5a5908b45879-195b14ae59f-00050304
# 
# Connect to obproxy ok
# +---------------------------------------------------------------+
# |                           obproxy-ce                          |
# +-----------+------+-----------------+-----------------+--------+
# | ip        | port | prometheus_port | rpc_listen_port | status |
# +-----------+------+-----------------+-----------------+--------+
# | 127.0.0.1 | 2883 | 2884            | 2885            | active |
# +-----------+------+-----------------+-----------------+--------+
# obclient -h127.0.0.1 -P2883 -uroot -p'UOY7x7evbn6rZcqCx010' -D oceanbase -A 
# 
# Connect to Obagent ok
# +-----------------------------------------------------------------+
# |                             obagent                             |
# +--------------+--------------------+--------------------+--------+
# | ip           | mgragent_http_port | monagent_http_port | status |
# +--------------+--------------------+--------------------+--------+
# | 172.31.36.97 | 8089               | 8088               | active |
# +--------------+--------------------+--------------------+--------+
# Connect to Prometheus ok
# +-----------------------------------------------------+
# |                      prometheus                     |
# +--------------------------+------+----------+--------+
# | url                      | user | password | status |
# +--------------------------+------+----------+--------+
# | http://172.31.36.97:9090 |      |          | active |
# +--------------------------+------+----------+--------+
# Connect to grafana ok
# +------------------------------------------------------------------+
# |                             grafana                              |
# +--------------------------------------+-------+----------+--------+
# | url                                  | user  | password | status |
# +--------------------------------------+-------+----------+--------+
# | http://172.31.36.97:3000/d/oceanbase | admin | admin    | active |
# +--------------------------------------+-------+----------+--------+
# demo running
# Trace ID: 657ca976-052f-11f0-8f49-0ee3e12982ad
# If you want to view detailed obd logs, please run: obd display-trace 657ca976-052f-11f0-8f49-0ee3e12982ad
# root@ip-172-31-36-97:~# 