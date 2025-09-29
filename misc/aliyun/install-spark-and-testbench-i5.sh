#!/bin/bash

# Reference：https://aws.amazon.com/cn/blogs/china/aws-graviton3-accelerates-spark-job-execution-benchmark/
# Alibaba Cloud Linux 3, 使用 ecs-user 账号登录.


sudo su - root
# 查询所有需要挂载的本地盘
disks="nvme1n1" 
for disk in $disks
do
    echo "[INFO] Start to create partition on $disk..."
    echo -e "g\nn\n1\n\n\nw" | fdisk /dev/$disk

    echo "[INFO] Start to create filesystem on $device..."
    partition=${disk}p1 && mkdir -p /data/$partition
    device="/dev/$partition" && mkfs -t xfs -f $device

    echo "[INFO] Start to modify /etc/fstab..."
    uuid=$(blkid | grep $partition | awk -F "\"" '{print $2}')
    echo "UUID=$uuid /data/$partition xfs  defaults,nofail  0  2" >> /etc/fstab
done
# cat /etc/fstab
mount -a && df -h
exit # 退出 root 用户，回到 ecs-user 用户

## 适配 
partition=nvme1n1p1
sudo chmod 777 /data/$partition
ln -s /data/$partition /home/ecs-user/data
## 后续步骤的所有软件都装在 /home/ecs-user/data/ 目录下，指向 /data/$partition/

# 设置软件栈版本：
echo "export HADOOP_VERSION=3.3.1" >> ~/.bashrc
echo "export HIVE_VERSION=3.1.3" >> ~/.bashrc
echo "export SPARK_VERSION=3.3.1" >> ~/.bashrc
echo "export SCALA_VERSION=2.12.18" >> ~/.bashrc

## aliyun 特有：
sudo vi /etc/hosts
# 添加
127.0.0.1 iZbp16qq4fgg0pvevgkg8iZ

# 生成密钥用于无密码登录：
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys
ssh localhost
exit

# 安装 OpenJDK
sudo yum install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel git gcc gcc-c++ patch htop python3 python3-pip screen
sudo pip3 install dool
JAVA_HOME="/usr/lib/jvm/jre"
echo "export JAVA_HOME=${JAVA_HOME}" >> ~/.bashrc
echo "export PATH=${JAVA_HOME}/bin/:${PATH}" >> ~/.bashrc
source ~/.bashrc
java -version

# 安装 Scala
cd ~/data
wget https://downloads.lightbend.com/scala/${SCALA_VERSION}/scala-${SCALA_VERSION}.tgz
tar zxf scala-${SCALA_VERSION}.tgz
ln -s $HOME/data/scala-${SCALA_VERSION} scala
echo "export SCALA_HOME=$HOME/data/scala" >> ~/.bashrc
echo "export PATH=$PATH:$HOME/data/scala/bin" >> ~/.bashrc
source  ~/.bashrc

# 安装 Maven
cd ~/data
wget https://mirrors.aliyun.com/apache/maven/maven-3/3.9.11/binaries/apache-maven-3.9.11-bin.tar.gz
tar zxf apache-maven-3.9.11-bin.tar.gz
ln -s ~/data/apache-maven-3.9.11 maven
MAVEN_HOME="$HOME/data/maven"
echo "export MAVEN_HOME=${MAVEN_HOME}" >> ~/.bashrc
echo "export PATH=${PATH}:${MAVEN_HOME}/bin" >> ~/.bashrc
source ~/.bashrc
mvn -v
mkdir -p /home/ecs-user/.m2
vi /home/ecs-user/.m2/settings.xml
##
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                              http://maven.apache.org/xsd/settings-1.0.0.xsd">
    <!-- 其他配置，包括mirror元素 -->
    <mirrors>
        <mirror>
		  <id>alimaven</id>
		  <mirrorOf>central</mirrorOf>
		  <name>阿里云Maven仓库</name>
		  <url>https://maven.aliyun.com/repository/central</url>
		</mirror>
    </mirrors>
    <!-- 其他设置 -->
</settings>
##


#安装 mysql 客户端，主要用于 Hive 组件：
cd ~/data
sudo yum install -y https://dev.mysql.com/get/mysql80-community-release-el8-1.noarch.rpm
sudo yum install -y mysql-community-client mysql-community-server --nogpgcheck
sudo systemctl start mysqld
sudo systemctl status mysqld
# 修改 MySQL 数据库 root 用户初始密码
cat << EOF > create_remote_login_user.sql
alter user 'root'@'localhost' identified with mysql_native_password by 'DoNotChangeMe@@123';
set global validate_password.policy=0;
alter user 'root'@'localhost' identified with mysql_native_password by 'gv2mysql';
create user 'root'@'%' identified with mysql_native_password by 'gv2mysql';
grant all privileges on *.* to 'root'@'%' with grant option;
flush privileges;
EOF
MYSQL_INIT_PASSWORD=$(sudo grep 'temporary password' /var/log/mysqld.log | tail -1 | awk '{print $NF}')
MYSQL_CMD_OPTIONS="--connect-expired-password -uroot -p${MYSQL_INIT_PASSWORD}"
mysql $MYSQL_CMD_OPTIONS < create_remote_login_user.sql
# 验证登录
mysql -uroot -p'gv2mysql' -e "show databases;"
# 创建 MySQL 数据库的 hive 用户
cat << EOF > create_hive_user.sql
CREATE DATABASE hive;
USE hive;
CREATE USER 'hive'@'localhost' IDENTIFIED BY 'Hive313Mysql';
GRANT ALL ON *.* TO 'hive'@'localhost';
FLUSH PRIVILEGES;
EOF
mysql -uroot -p'gv2mysql' < create_hive_user.sql

# 安装和配置 Hadoop 软件
# 首先确定实例的架构（x86_64 或 aarch64），后续会下载对应架构的 Hadoop 软件包：
cd ~/data
ARCH=$(arch)
if [[ "$ARCH" == "aarch64" ]]; then
    ARCH="-aarch64"
elif [[ "$ARCH" == "x86_64" ]]; then
    ARCH=""
else
    echo "$ARCH not supported"
    exit 1
fi

# 下载指定架构的 Hadoop 软件包：
wget https://archive.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION$ARCH.tar.gz
tar zxf hadoop-$HADOOP_VERSION$ARCH.tar.gz
ln -s hadoop-$HADOOP_VERSION $HOME/data/hadoop 
echo "export HADOOP_HOME=$HOME/data/hadoop" >> ~/.bashrc
echo "export PATH=$PATH:$HOME/data/hadoop/bin:$HOME/data/hadoop/sbin" >> ~/.bashrc
source  ~/.bashrc
mkdir $HADOOP_HOME/tmp
mkdir $HADOOP_HOME/hdfs
mkdir $HADOOP_HOME/hdfs/name
mkdir $HADOOP_HOME/hdfs/data
hadoop version

# 配置 Hadoop 环境，首先修改 Hadoop-env.sh 脚本：
IPADDR=localhost
cp $HADOOP_HOME/etc/hadoop/hadoop-env.sh $HADOOP_HOME/etc/hadoop/hadoop-env.sh.bak
echo "export JAVA_HOME=${JAVA_HOME}" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh

# 修改 core-site.xml 配置文件
cp $HADOOP_HOME/etc/hadoop/core-site.xml $HADOOP_HOME/etc/hadoop/core-site.xml.bak
cat << EOF > $HADOOP_HOME/etc/hadoop/core-site.xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://$IPADDR:9000</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>$HOME/data/hadoop/tmp</value>
    </property>
    <property>
        <name>hadoop.proxyuser.hive.hosts</name>
        <value>*</value>
    </property>
    <property>
        <name>hadoop.proxyuser.hive.groups</name>
        <value>*</value>
    </property>
</configuration>
EOF

# 修改 hdfs-site.xml 配置文件：
cp $HADOOP_HOME/etc/hadoop/hdfs-site.xml $HADOOP_HOME/etc/hadoop/hdfs-site.xml.bak
cat << EOF > $HADOOP_HOME/etc/hadoop/hdfs-site.xml
<?xml version="1.0"?>
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
    <property>
        <name>dfs.name.dir</name>
        <value>$HADOOP_HOME/hdfs/name</value>
    </property>
    <property>
        <name>dfs.data.dir</name>
        <value>$HADOOP_HOME/hdfs/data</value>
    </property>
</configuration>
EOF

# 修改 yarn-site.xml 配置文件：
cp $HADOOP_HOME/etc/hadoop/yarn-site.xml $HADOOP_HOME/etc/hadoop/yarn-site.xml.bak
cat << EOF > $HADOOP_HOME/etc/hadoop/yarn-site.xml
<?xml version="1.0"?>
<configuration>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>${IPADDR}</value>
    </property>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
</configuration>
EOF

# 修改 mapred-site.xml 配置文件：
cp $HADOOP_HOME/etc/hadoop/mapred-site.xml $HADOOP_HOME/etc/hadoop/mapred-site.xml.bak
cat << EOF > $HADOOP_HOME/etc/hadoop/mapred-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.env</name>
        <value>HADOOP_MAPRED_HOME=$HOME/data/hadoop</value>
    </property>
    <property>
        <name>mapreduce.map.env</name>
        <value>HADOOP_MAPRED_HOME=$HOME/data/hadoop</value>
    </property>
    <property>
        <name>mapreduce.reduce.env</name>
        <value>HADOOP_MAPRED_HOME=/$HOME/data/hadoop</value>
    </property>
</configuration>
EOF

# 初始化 HDFS 节点，启动 DFS 和 Yarn：
$HADOOP_HOME/bin/hdfs namenode -format
$HADOOP_HOME/sbin/start-dfs.sh
grep clusterID $(find $HADOOP_HOME/ -name VERSION)
$HADOOP_HOME/sbin/start-yarn.sh
jps

# 安装和配置 Hive 软件
# 下载和安装 Hive 软件：
cd ~/data
wget https://archive.apache.org/dist/hive/hive-$HIVE_VERSION/apache-hive-$HIVE_VERSION-bin.tar.gz
tar zxf apache-hive-$HIVE_VERSION-bin.tar.gz
ln -s $HOME/data/apache-hive-$HIVE_VERSION-bin hive
echo "export HIVE_HOME=$HOME/data/hive" >> ~/.bashrc
echo "export PATH=$PATH:$HOME/data/hive/bin:$HOME/data/hive/sbin" >> ~/.bashrc
source  ~/.bashrc

# 修改 hive-site.xml  配置文件：
cd $HIVE_HOME/conf
wget https://github.com/eric-yq/ec2-test-suite/raw/refs/heads/main/misc/spark-tpcds/hive-site.xml
sed -i "s/ec2-user/ecs-user\/data/g" hive-site.xml

# 配置 MySQL Connector
cd ~/data
wget https://downloads.mysql.com/archives/get/p/3/file/mysql-connector-java-5.1.49.tar.gz
tar zxf mysql-connector-java-5.1.49.tar.gz
cp mysql-connector-java-5.1.49/mysql-connector-java-5.1.49.jar $HIVE_HOME/lib/
sudo ln -s $HIVE_HOME/lib/mysql-connector-java-5.1.49.jar /usr/share/java/mysql-connector-java.jar
$HIVE_HOME/bin/schematool -dbType mysql -initSchema

#启动 Hive 服务
nohup hive --service metastore &
nohup hive --service hiveserver2 &

# 可通过 jps 查看启动的进程，并通过 hive 命令查看目前存在的数据库：
jps
hive -e "show databases;"

# 安装和配置 Spark 软件
cd ~/data
wget https://archive.apache.org/dist/spark/spark-$SPARK_VERSION/spark-$SPARK_VERSION-bin-hadoop3.tgz
tar zxf spark-$SPARK_VERSION-bin-hadoop3.tgz
ln -s spark-$SPARK_VERSION-bin-hadoop3 spark
echo "export SPARK_HOME=$HOME/data/spark" >> ~/.bashrc
echo "export PATH=$PATH:$HOME/data/spark/bin:$HOME/spark/sbin" >> ~/.bashrc
source ~/.bashrc

# 配置 Spark 软件
cp $HIVE_HOME/conf/hive-site.xml $SPARK_HOME/conf/
cp $HADOOP_HOME/etc/hadoop/core-site.xml $HADOOP_HOME/etc/hadoop/hdfs-site.xml $SPARK_HOME/conf/
cp $SPARK_HOME/conf/log4j2.properties.template $SPARK_HOME/conf/log4j2.properties
sed -i "s/rootLogger.level = info/rootLogger.level = error/g" $SPARK_HOME/conf/log4j2.properties
ln -s /usr/share/java/mysql-connector-java.jar $SPARK_HOME/jars/mysql-connector-java.jar

# 启动 Spark Local 集群
$SPARK_HOME/sbin/start-all.sh

# 通过下面命令进行初步验证，spark-example 将完成指定位数的 Pi 值计算。
spark-sql -e "show databases;"
spark-submit --class org.apache.spark.examples.SparkPi \
  $SPARK_HOME/examples/jars/spark-examples_2.12-3.3.1.jar 100

################################################################################################
# 安装和配置 TPC-DS 测试工具
cd ~/data
git clone https://github.com/hortonworks/hive-testbench.git

## 方法 2： 如果上述方法有问题，可能是  tpcds_kit.zip 下载失败导致的，可以尝试下面的方法
cd $HOME/data/hive-testbench/tpcds-gen
# （1）将 Makefile 中的下面 3 行注释掉
#tpcds_kit.zip:
#       curl https://public-repo-1.hortonworks.com/hive-testbench/tpcds/README
#       curl --output tpcds_kit.zip https://public-repo-1.hortonworks.com/hive-testbench/tpcds/TPCDS_Tools.zip
# （2）手动下载 tpcds_kit.zip
wget https://github.com/eric-yq/ec2-test-suite/raw/refs/heads/main/misc/spark-tpcds/tpcds_kit.zip

## gcc 10 以上版本，需要做如下修改
sudo su - root
mv /usr/bin/gcc /usr/bin/gcc-impl
ARCH=$(arch)
if [[ "$ARCH" == "aarch64" ]]; then
    cat > /usr/bin/gcc  << EOF
#! /bin/sh  
/usr/bin/gcc-impl -fsigned-char -fcommon \$@
EOF
elif [[ "$ARCH" == "x86_64" ]]; then
    cat > /usr/bin/gcc  << EOF
#! /bin/sh  
/usr/bin/gcc-impl -fcommon \$@
EOF
else
    echo "$ARCH not supported"
    exit 1
fi
chmod +x /usr/bin/gcc
## 退出root 用户
exit

## 回到 ecs-user 用户操作
cd $HOME/data/hive-testbench/
sudo yum install -y unzip
./tpcds-build.sh

# 配置 benchmark 工具：
IPADDR=localhost
sed -i.bak "s/localhost:2181\/;serviceDiscoveryMode=zooKeeper;zooKeeperNamespace=hiveserver2?tez.queue.name=default/${IPADDR}:10000\//" $HOME/data/hive-testbench/tpcds-setup.sh
sed -i.bak "s/hive.optimize.sort.dynamic.partition.threshold=0/hive.optimize.sort.dynamic.partition=true/" $HOME/data/hive-testbench/settings/*.sql

################################################################################################
# 生成测试数据集
# 通过指定 SF 的值，设置程序需要生成的数据量，本文中 SF=100 表示生成 100GB 的数据量。
# 根据生成的数据量大小差异，此过程可能会持续数分钟到数小时不等。
cd $HOME/data/hive-testbench
SF=600
./tpcds-setup.sh $SF

################################################################################################
# 执行全部的 SQL 分析任务
# 待数据全部完成之后，预先准备 Benchmark 过程中需要的一些结果目录：
cd ~/data
SUT_NAME="spark-tpcds"
PN=$(sudo cloud-init query ds.meta_data.instance.instance-type)
DATA_DIR=~/data/${PN}_${SUT_NAME}
CFG_DIR=$DATA_DIR/system-infomation
TPCDS_RESULT_DIR=$DATA_DIR/spark-tpcds-result
LOG_DIR=$DATA_DIR/logs
mkdir -p $DATA_DIR $CFG_DIR $TPCDS_RESULT_DIR $LOG_DIR
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RESULT_PATH="$TPCDS_RESULT_DIR/$TIMESTAMP"
mkdir -p $RESULT_PATH
RESULT_SUMMARY="$RESULT_PATH/result_summary_spark_tpc-ds.txt"

# 逐个执行 *.sql 文件的方式执行 Benchmark：
echo "[$TIMESTAMP] Start Spark TPC-DS Benchmark(SF=$SF) on $PN ...... " > $RESULT_SUMMARY
cd $HOME/data/hive-testbench/spark-queries-tpcds
LIST=$(ls *.sql)
for i in $LIST; do
    RESULT_LOG="$RESULT_PATH/$i.log"
    RESULT_OUT="$RESULT_PATH/$i.out"
    spark-sql --driver-memory 4G --database tpcds_bin_partitioned_orc_$SF -f $i \ 1>$RESULT_OUT 2>$RESULT_LOG
    execution_time=$(grep "Time taken" $RESULT_LOG)
    echo "[$(date +%Y%m%d-%H%M%S)] $i : $execution_time " >> $RESULT_SUMMARY
done

################################################################################################
# 查看 Benchmark 执行结果
## 当每一个 SQL 文件在执行时，可以通过下面步骤查看执行进程
cd $RESULT_PATH
tail -f result_summary_spark_tpc-ds.txt