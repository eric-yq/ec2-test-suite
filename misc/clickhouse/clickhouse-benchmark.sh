#!/bin/bash

## This is a cloud-init script for ubuntu 22.04
## for instance store EC2 instance.

## (optional) mount nvme disk
## 使用最后一个 InstanceStore 盘，并挂载
### ！！！ 这个顺序也不一定啊 ！！！！
DISK=$(lsblk -n -o NAME,TYPE | grep disk | grep nvme | awk -F" " '{print $1}' | tail -n 1)
echo $DISK
## 在 i3 ： xvda 是 EBS root，其他InstanceStore按照nvme0n1,nvme1n1...
# [root@ip-172-31-19-21 ~]# lsblk -n -o NAME,TYPE | grep disk
# xvda        disk
# nvme0n1     disk
## 在 i4g/i4i之后实例 ： nvme0n1 是 EBS root，其他 InstanceStore按照nvme1n1,nvme2n1 排序
# root@ip-172-31-43-89:~# lsblk -n -o NAME,TYPE | grep disk 
# nvme0n1      disk
# nvme1n1      disk

# 挂载数据盘
DEVICE=/dev/$DISK
DATADIR=/var/lib/clickhouse
mkfs -t xfs $DEVICE
mkdir -p $DATADIR
mount $DEVICE $DATADIR
mkdir -p $DATADIR/clickbench
cd $DATADIR/clickbench

## Perform clickbench benchmark
BASE_URL='https://raw.githubusercontent.com/ClickHouse/ClickBench/main/clickhouse/'
# apt-get update
# apt-get install -y wget curl
# apt-get install -y python3-pip && pip3 install dool
# dool -cmndryt 10

wget $BASE_URL/{benchmark.sh,run.sh,create.sql,queries.sql}
chmod +x *.sh
./benchmark.sh 2>&1 | tee log ## 会自动安装 clickhouse 

echo $BASE_URL >> log
curl 'http://169.254.169.254/latest/meta-data/instance-type' >> log

###############################################################################
# For TPC-DS benchmark
DATADIR=/var/lib/clickhouse
ln -s $DATADIR /data
cd /data
export SCALE=600
## 生成工具
git clone https://github.com/Altinity/tpc-ds.git /data/tpc-ds
cd /data/tpc-ds/bin/
AAA=$(grep LINUX_CFLAGS ../tpc-ds-tool/v2.11.0rc2/tools/Makefile.suite)
BBB=$AAA" -fcommon"
sed  -i.bak "s/$AAA/$BBB/g"  ../tpc-ds-tool/v2.11.0rc2/tools/Makefile.suite
diff ../tpc-ds-tool/v2.11.0rc2/tools/Makefile.suite*
apt install -y yacc flex gcc make
./build-tool.sh
ll -trh ../tpc-ds-tool/v2.11.0rc2/tools/ds*
## 建表：25 个表
clickhouse-client --queries-file ../schema/tpcds.sql
clickhouse-client -n --query="use tpcds; show tables;" | wc -l
## 生成数据: 下面命令在 tpc-ds/data 目录生成 600G 数据
rm -rf ../data/
sed -i "s/PARALLEL_STREAMS_COUNT=64/PARALLEL_STREAMS_COUNT=$(nproc)/g" ./generate-data.sh
nohup bash ./generate-data.sh $SCALE &
sleep 1
ll -htr ../data
du -smh ../data

## 导入数据 可以使用 screen -R ttt -L 执行。
table_list=$(clickhouse-client -n --query="use tpcds; show tables;")
for i in $table_list
do
  for filename in ../data/${i}_*.dat; 
  do 
  {
    clickhouse-client --format_csv_delimiter="|" --query="INSERT INTO tpcds.${i} FORMAT CSV" \
      --max_memory_usage=128G --max_threads=$(nproc) \
      --max_partitions_per_insert_block=0 --progress on < $filename
  }
  done 
  echo "Complete to load date files into table $i ."
done
echo "Complete to load ALL data files into database ."

## 命令行查询：查询 tpcds 表数据量和所占容量
table_list=$(clickhouse-client -n --query="use tpcds; show tables;")
data_files_size=$(du -smh ../data/)
echo "[Summary]"    
echo "All data files（*.dat）size: $data_files_size"    
database_size=$(clickhouse-client --query="select database, table, sum(rows) as row,formatReadableSize(sum(data_uncompressed_bytes)) as ysq,formatReadableSize(sum(data_compressed_bytes)) as ysh, round(sum(data_compressed_bytes) / sum(data_uncompressed_bytes) * 100, 0) ys_rate from system.parts where database = 'tpcds' group by database,table order by table;")  
echo "TPC-DS database size(SCALE=600):"  
echo "$database_size" 
## 生成查询语句
export SCALE=600
cd /data/tpc-ds/bin/
./generate-queries.sh $SCALE
cd ../queries
sed -i "s/partial_merge_join = 1,//g" *
## 执行查询
# for i in $(seq 1 99)
clickhouse restart
sleep 3
rm -rf *.log
LIST="2 3 7 8 9 11 15 17 19 22 23 24 25 26 27 28 29 31 33 34 38 39 42 43 44 45 46 50 51 53 54 55 56 59 60 62 63 65 67 68 71 73 74 76 78 83 84 85 87 88 89 90 91 93 96 97 99"
for i in $LIST
do
    echo "[Info][$(date +%Y%m%d%H%M%S)] Start to perform SQL file: query_${i}.sql"
    clickhouse-client --time --progress --queries-file query_${i}.sql \
      1>query_${i}.sql.log  2>&1
    echo "[Info][$(date +%Y%m%d%H%M%S)] Complete to perform SQL file: query_${i}.sql"
    sleep 1
done

## 查询 *.log 中的异常，列举出匹配的文件：
grep -l "Exception" /data/tpc-ds/queries/query*.log

## 查询 *.log 中的异常，列举出不匹配的文件，即可以执行成功的 SQL 文件
grep -L "Exception" /data/tpc-ds/queries/query*.log

## 所有 SQL 执行完后，查询执行成功的 SQL 的时间，
instance_type=$(dmidecode -s system-product-name | tr ' ' '_')
tail -n 1 $(grep -L "DB::Exception:" /data/tpc-ds/queries/query*.log) \
  > tpcds-summary-${instance_type}.txt


## 文本处理：获取执行成功 SQL 文件名
sed -n '1~3p' tpcds-summary-${instance_type}.txt
## 文本处理：获取每个 SQL 文件名对应的执行时间
sed -n '2~3p' tpcds-summary-${instance_type}.txt

cd ..
tar czf queries_${instance_type}.tar.gz queries


