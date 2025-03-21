#!/bin/bash
# Ubuntu 22.04

sudo tee /etc/sysctl.d/99-os-performance.conf > /dev/null << 'EOF'
vm.max_map_count = 1048576
fs.file-max = 20000000
fs.nr_open = 20000000
fs.aio-max-nr = 1048576
EOF
sysctl -p /etc/sysctl.d/99-os-performance.conf
    
# 安装all-in-one 版本
bash -c "$(curl -s https://obbusiness-private.oss-cn-shanghai.aliyuncs.com/download-center/opensource/oceanbase-all-in-one/installer.sh)"
source ~/.oceanbase-all-in-one/bin/env.sh
obd demo -c oceanbase-ce 

# 修改默认demo集群的内存配置
MEM_TOTAL_GB=$(free -g |grep Mem | awk -F " " '{print $2}')
let XXX=${MEM_TOTAL_GB}-8
sed -i.bak "s/memory_limit: 6G/memory_limit: ${XXX}G/g" /root/.obd/cluster/demo/config.yaml
obd cluster stop demo        
obd cluster reload demo   
obd cluster start demo

# 获取root@sys密码
ROOT_PASSWORD=$(grep root_password ~/.obd/cluster/demo/config.yaml | awk -F " " '{print $NF}')

##########################################################################################
# 安装 BenchmarkSQL 工具
apt install -y openjdk-17-jdk unzip net-tools python3-pip net-toolshtop iotop ant
pip3 install dool
# wget https://jaist.dl.sourceforge.net/project/benchmarksql/benchmarksql-5.0.zip
# unzip benchmarksql-5.0.zip
### 参考下面文档进行适配：https://www.oceanbase.com/docs/common-oceanbase-database-cn-1000000002013258#6-title-%E9%80%82%E9%85%8D%20Benchmark%20SQL5
wget https://github.com/eric-yq/ec2-test-suite/raw/refs/heads/main/misc/oceanbase/benchmarksql-5.0_for_oceanbase_tpcc.tar.gz
tar zxf benchmarksql-5.0_for_oceanbase_tpcc.tar.gz
cd benchmarksql-5.0
ant

# 下载jdbc mysql驱动文件
cd /root/
wget https://downloads.mysql.com/archives/get/p/3/file/mysql-connector-java-5.1.47.tar.gz
tar zxf mysql-connector-java-5.1.47.tar.gz
mv mysql-connector-java-5.1.47/*.jar benchmarksql-5.0/lib/

##########################################################################################
# 准备数据库测试环境
## 创建 test 租户
# 首先查看剩余资源
ROOT_PASSWORD=$(grep root_password ~/.obd/cluster/demo/config.yaml | awk -F " " '{print $NF}')
MEM_FREE_GB=$(obclient -h127.0.0.1 -P2881 -uroot -p${ROOT_PASSWORD} -Doceanbase -A -N -s -e \
  "SELECT 
    round((mem_capacity - mem_assigned)/1024/1024/1024, 0) AS mem_free_gb 
   FROM oceanbase.gv\$ob_servers 
   WHERE zone = 'zone1';")
let YYY=${MEM_FREE_GB}-2
CPU_FREE_NUM=$(obclient -h127.0.0.1 -P2881 -uroot -p${ROOT_PASSWORD} -Doceanbase -A -N -s -e \
  "SELECT 
    (cpu_capacity_max - cpu_assigned_max) AS cpu_free_num 
  FROM oceanbase.gv\$ob_servers 
  WHERE zone = 'zone1';")

# 创建unit，pool和租户。根据上面查询到全部剩余资源，调整unit配置
obclient -h127.0.0.1 -P2881 -uroot -p${ROOT_PASSWORD} -Doceanbase -A -N -s -e \
  "CREATE RESOURCE UNIT test 
    MAX_CPU=${CPU_FREE_NUM}, 
    MIN_CPU=${CPU_FREE_NUM}, 
    MEMORY_SIZE='${YYY}G',
    LOG_DISK_SIZE='5G';"
obclient -h127.0.0.1 -P2881 -uroot -p${ROOT_PASSWORD} -Doceanbase -A -N -s -e \
  "CREATE RESOURCE POOL test UNIT='test',UNIT_NUM=1,ZONE_LIST=('zone1');"
obclient -h127.0.0.1 -P2881 -uroot -p${ROOT_PASSWORD} -Doceanbase -A -N -s -e \
  "CREATE TENANT test 
    charset='utf8mb4',
    replica_num=1, 
    zone_list=('zone1'),
    primary_zone='zone1',
    resource_pool_list=('test');"
    
# 为租户 test 的 root 用户创建密码
obclient -h127.0.0.1 -P2881 -uroot@test -e "ALTER USER root IDENTIFIED BY 'gv2mysql';"

# 创建数据库
obclient -h127.0.0.1 -P2881 -uroot@test -p'gv2mysql' -e "CREATE DATABASE tpccdb;"
# obclient -h127.0.0.1 -P2881 -uroot@test -p'gv2mysql' -e "DROP DATABASE tpccdb;"

# 创建配置文件
cat > ~/benchmarksql-5.0/run/props.ob  << EOF
db=oceanbase
driver=com.mysql.jdbc.Driver
conn=jdbc:mysql://127.0.0.1:2881/tpccdb?useUnicode=true&characterEncoding=utf-8&rewriteBatchedStatements=true&allowMultiQueries=true
user=root@test
password=gv2mysql

warehouses=100
loadWorkers=32

terminals=$(nproc)
//To run specified transactions per terminal- runMins must equal zero
runTxnsPerTerminal=0
//To run for specified minutes- runTxnsPerTerminal must equal zero
runMins=10
//Number of total transactions per minute
limitTxnsPerMin=0

//Set to true to run in 4.x compatible mode. Set to false to use the
//entire configured database evenly.
terminalWarehouseFixed=true

//The following five values must add up to 100
newOrderWeight=45
paymentWeight=43
orderStatusWeight=4
deliveryWeight=4
stockLevelWeight=4

// Directory name to create for collecting detailed result data.
// Comment this out to suppress.
resultDirectory=my_result_%tY-%tm-%td_%tH%tM%tS
// osCollectorScript=./misc/os_collector_linux.py
// osCollectorInterval=1
EOF

# 创建建表脚本
vi ~/benchmarksql-5.0/run/sql.common/tableCreates_parts.sql
#####
create table bmsql_config (
cfg_name    varchar(30) primary key,
cfg_value   varchar(50)
);

-- drop tablegroup tpcc_group;
create tablegroup tpcc_group binding true partition by hash partitions 9;

create table bmsql_warehouse (
   w_id        integer   not null,
   w_ytd       decimal(12,2),
   w_tax       decimal(4,4),
   w_name      varchar(10),
   w_street_1  varchar(20),
   w_street_2  varchar(20),
   w_city      varchar(20),
   w_state     char(2),
   w_zip       char(9),
   primary key(w_id)
)tablegroup='tpcc_group' partition by hash(w_id) partitions 9;

create table bmsql_district (
   d_w_id       integer       not null,
   d_id         integer       not null,
   d_ytd        decimal(12,2),
   d_tax        decimal(4,4),
   d_next_o_id  integer,
   d_name       varchar(10),
   d_street_1   varchar(20),
   d_street_2   varchar(20),
   d_city       varchar(20),
   d_state      char(2),
   d_zip        char(9),
   PRIMARY KEY (d_w_id, d_id)
)tablegroup='tpcc_group' partition by hash(d_w_id) partitions 9;

create table bmsql_customer (
   c_w_id         integer        not null,
   c_d_id         integer        not null,
   c_id           integer        not null,
   c_discount     decimal(4,4),
   c_credit       char(2),
   c_last         varchar(16),
   c_first        varchar(16),
   c_credit_lim   decimal(12,2),
   c_balance      decimal(12,2),
   c_ytd_payment  decimal(12,2),
   c_payment_cnt  integer,
   c_delivery_cnt integer,
   c_street_1     varchar(20),
   c_street_2     varchar(20),
   c_city         varchar(20),
   c_state        char(2),
   c_zip          char(9),
   c_phone        char(16),
   c_since        timestamp,
   c_middle       char(2),
   c_data         varchar(500),
   PRIMARY KEY (c_w_id, c_d_id, c_id)
)tablegroup='tpcc_group' partition by hash(c_w_id) partitions 9;

create table bmsql_history (
   hist_id  integer,
   h_c_id   integer,
   h_c_d_id integer,
   h_c_w_id integer,
   h_d_id   integer,
   h_w_id   integer,
   h_date   timestamp,
   h_amount decimal(6,2),
   h_data   varchar(24)
)tablegroup='tpcc_group' partition by hash(h_w_id) partitions 9;

create table bmsql_new_order (
   no_w_id  integer   not null ,
   no_d_id  integer   not null,
   no_o_id  integer   not null,
   PRIMARY KEY (no_w_id, no_d_id, no_o_id)
)tablegroup='tpcc_group' partition by hash(no_w_id) partitions 9;

create table bmsql_oorder (
   o_w_id       integer      not null,
   o_d_id       integer      not null,
   o_id         integer      not null,
   o_c_id       integer,
   o_carrier_id integer,
   o_ol_cnt     integer,
   o_all_local  integer,
   o_entry_d    timestamp,
   PRIMARY KEY (o_w_id, o_d_id, o_id)
)tablegroup='tpcc_group' partition by hash(o_w_id) partitions 9;

create table bmsql_order_line (
   ol_w_id         integer   not null,
   ol_d_id         integer   not null,
   ol_o_id         integer   not null,
   ol_number       integer   not null,
   ol_i_id         integer   not null,
   ol_delivery_d   timestamp,
   ol_amount       decimal(6,2),
   ol_supply_w_id  integer,
   ol_quantity     integer,
   ol_dist_info    char(24),
   PRIMARY KEY (ol_w_id, ol_d_id, ol_o_id, ol_number)
)tablegroup='tpcc_group' partition by hash(ol_w_id) partitions 9;

create table bmsql_item (
   i_id     integer      not null,
   i_name   varchar(24),
   i_price  decimal(5,2),
   i_data   varchar(50),
   i_im_id  integer,
   PRIMARY KEY (i_id)
);

create table bmsql_stock (
   s_w_id       integer       not null,
   s_i_id       integer       not null,
   s_quantity   integer,
   s_ytd        integer,
   s_order_cnt  integer,
   s_remote_cnt integer,
   s_data       varchar(50),
   s_dist_01    char(24),
   s_dist_02    char(24),
   s_dist_03    char(24),
   s_dist_04    char(24),
   s_dist_05    char(24),
   s_dist_06    char(24),
   s_dist_07    char(24),
   s_dist_08    char(24),
   s_dist_09    char(24),
   s_dist_10    char(24),
   PRIMARY KEY (s_w_id, s_i_id)
)tablegroup='tpcc_group' use_bloom_filter=true partition by hash(s_w_id) partitions 9;
#####

## 执行建表语句
cd ~/benchmarksql-5.0/run
./runSQL.sh props.ob sql.common/tableCreates_parts.sql
obclient -h127.0.0.1 -P2881 -uroot@test -p'gv2mysql' -D tpccdb -e "show tables;"

## 加载数据
obclient -h127.0.0.1 -P2881 -uroot@test -p'gv2mysql' -D tpccdb -e "SET GLOBAL ob_query_timeout = 3600000000;"
./runLoader.sh props.ob

## 补充创建两个索引
obclient -h127.0.0.1 -P2881 -uroot@test -p'gv2mysql' -D tpccdb -e \
  "create index bmsql_customer_idx1 on  bmsql_customer (c_w_id, c_d_id, c_last, c_first) local;
  create  index bmsql_oorder_idx1 on  bmsql_oorder (o_w_id, o_d_id, o_carrier_id, o_id) local;"

## (可选）对应租户做一次集群合并（major freeze）
obclient -h127.0.0.1 -P2881 -uroot@test -p'gv2mysql' -D tpccdb -e "ALTER SYSTEM MAJOR FREEZE;"
ROOT_PASSWORD=$(grep root_password ~/.obd/cluster/demo/config.yaml | awk -F " " '{print $NF}')
obclient -h127.0.0.1 -P2881 -uroot -p${ROOT_PASSWORD} -D oceanbase -A -e  "SELECT * FROM oceanbase.CDB_OB_ZONE_MAJOR_COMPACTION;"  #直到STATUS都是IDLE

## 执行测试
cd ~/benchmarksql-5.0/run
./runBenchmark.sh props.ob



##########################################################################################
## sysbench 测试
IPADDR="172.31.5.213"
# cleanup：
sysbench oltp_read_write.lua --mysql-host=$IPADDR --mysql-port=2881 --mysql-db=testdb --mysql-user=root@test --mysql-password=gv2mysql --table_size=1000000 --tables=30 --rand-type=uniform --threads=32  --report-interval=10 --time=600 cleanup

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



obclient -h127.0.0.1 -P2881 -uroot@sys -p'UOY7x7evbn6rZcqCx010' -Doceanbase -A

mysql -h 127.0.0.1 -uroot -P2883 -p'UOY7x7evbn6rZcqCx010'
mysql> create database tpcc;
mysql> CREATE USER 'tpcc'@'%' IDENTIFIED BY '123456';
mysql> GRANT ALL ON tpcc.* TO 'tpcc'@'%';
mysql> exit




















# Reference: https://www.oceanbase.com/docs/common-oceanbase-database-cn-1000000002013258
# ......
# +---------------------------------------------+
# |                 oceanbase-ce                |
# +-----------+---------+------+-------+--------+
# | ip        | version | port | zone  | status |
# +-----------+---------+------+-------+--------+
# | 127.0.0.1 | 4.3.5.0 | 2881 | zone1 | ACTIVE |
# +-----------+---------+------+-------+--------+
# obclient -h127.0.0.1 -P2881 -uroot -p'UOY7x7evbn6rZcqCx010' -Doceanbase -A
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
# obclient -h127.0.0.1 -P2883 -uroot -p'UOY7x7evbn6rZcqCx010' -Doceanbase -A 
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