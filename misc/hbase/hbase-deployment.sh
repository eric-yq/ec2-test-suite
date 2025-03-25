#!/bin/bash 


sudo su - root
# 查询所有需要挂载的本地盘
DISKS=$(lsblk -n -o NAME,TYPE,PTTYPE,PARTTYPE --list | grep disk | grep -v gpt | awk -F" " '{print $1}')
echo $DISKS

# 挂载数据盘
for disk in $DISKS
do
	echo "[INFO] Start to handle $disk..."
	# 格式化磁盘
	DEVICE=/dev/$disk
	mkfs -t xfs $DEVICE
	UUID=$(blkid | grep $disk| awk -F "\"" '{print $2}')
	
	# 创建挂载目录
	MOUNTDIR="/mnt/$disk"
	mkdir -p $MOUNTDIR
	
	# fstab 添加表项
	echo "UUID=$UUID $MOUNTDIR xfs  defaults,nofail  0  2" >> /etc/fstab
done
# cat /etc/fstab
mount -a && df -h 

# 退出root用户
exit


sudo su - ec2-user
# 设置软件栈版本：
echo "export HADOOP_VERSION=3.3.5" >> ~/.bashrc
echo "export HBASE_VERSION=2.5.11" >> ~/.bashrc
# 工作目录设置在 nvme 本地盘
echo "export WORK_DIR=/mnt/nvme1n1" >> ~/.bashrc
source ~/.bashrc
sudo chmod -R 777 $WORK_DIR

sudo yum install -y java-11-amazon-corretto-devel python3-pip iotop htop
sudo pip3 install dool
JAVA_HOME="/usr/lib/jvm/jre"
echo "export JAVA_HOME=${JAVA_HOME}" >> ~/.bashrc
echo "export PATH=${JAVA_HOME}/bin/:${PATH}" >> ~/.bashrc
source ~/.bashrc
java -version

# 生成密钥用于无密码登录：
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys
ssh $(hostname -I)
exit

# 安装和配置 Hadoop 软件
# 首先确定实例的架构（x86_64 或 aarch64），后续会下载对应架构的 Hadoop 软件包：
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
cd $WORK_DIR
wget https://archive.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION$ARCH.tar.gz
# 备选：wget https://mirrors.aliyun.com/apache/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION$ARCH.tar.gz
tar zxf hadoop-$HADOOP_VERSION$ARCH.tar.gz
ln -s hadoop-$HADOOP_VERSION ${WORK_DIR}/hadoop
echo "export HADOOP_HOME=${WORK_DIR}/hadoop" >> ~/.bashrc
source  ~/.bashrc
mkdir $HADOOP_HOME/tmp
mkdir $HADOOP_HOME/hdfs
mkdir $HADOOP_HOME/hdfs/name
mkdir $HADOOP_HOME/hdfs/data
$HADOOP_HOME/bin/hadoop version

# 配置 Hadoop 环境，首先修改 Hadoop-env.sh 脚本：
# IPADDR=localhost
# IPADDR=$(ip addr show | grep -w inet | grep -v 127.0.0.1 | awk '{print $2}' | cut -d/ -f1)
IPADDR=$(hostname -I | tr -d ' ')
echo "export JAVA_HOME=${JAVA_HOME}" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh

# 修改 core-site.xml 配置文件：
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
        <value>${HADOOP_HOME}/tmp</value>
    </property>
</configuration>
EOF

# 修改 hdfs-site.xml 配置文件：
cat << EOF > $HADOOP_HOME/etc/hadoop/hdfs-site.xml
<?xml version="1.0"?>
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
    <property>
        <name>dfs.name.dir</name>
        <value>${HADOOP_HOME}/hdfs/name</value>
    </property>
    <property>
        <name>dfs.data.dir</name>
        <value>${HADOOP_HOME}/hdfs/data</value>
    </property>
</configuration>
EOF

# 修改 yarn-site.xml 配置文件：
cat << EOF > $HADOOP_HOME/etc/hadoop/yarn-site.xml
<?xml version="1.0"?>
<configuration>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>$IPADDR</value>
    </property>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
</configuration>
EOF

# 修改 mapred-site.xml 配置文件：
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
        <value>HADOOP_MAPRED_HOME=$HADOOP_HOME</value>
    </property>
    <property>
        <name>mapreduce.map.env</name>
        <value>HADOOP_MAPRED_HOME=$HADOOP_HOME</value>
    </property>
    <property>
        <name>mapreduce.reduce.env</name>
        <value>HADOOP_MAPRED_HOME=$HADOOP_HOME</value>
    </property>
</configuration>
EOF

# 初始化 HDFS 节点，启动 DFS 和 Yarn：
$HADOOP_HOME/bin/hdfs namenode -format
$HADOOP_HOME/sbin/start-dfs.sh
# grep clusterID $(find $HADOOP_HOME/ -name VERSION)
$HADOOP_HOME/sbin/start-yarn.sh
jps

## 安装 Hbase
cd $WORK_DIR
wget https://downloads.apache.org/hbase/$HBASE_VERSION/hbase-${HBASE_VERSION}-hadoop3-bin.tar.gz
tar zxf hbase-${HBASE_VERSION}-hadoop3-bin.tar.gz
ln -s hbase-${HBASE_VERSION}-hadoop3 ${WORK_DIR}/hbase
echo "export HBASE_HOME=${WORK_DIR}/hbase" >> ~/.bashrc
source  ~/.bashrc

mkdir -p $HADOOP_HOME/hdfs/data/{zookeeper,hbase-tmp,hbase-pid,hbase-logs}

cat > $HBASE_HOME/conf/hbase-site.xml << EOL
<configuration>
    <property>
        <name>hbase.cluster.distributed</name>
        <value>true</value>
    </property>
    <property>
        <name>hbase.rootdir</name>
        <value>hdfs://$IPADDR:9000/hbase</value>
    </property>
    <property>
        <name>hbase.zookeeper.property.dataDir</name>
        <value>${HADOOP_HOME}/hdfs/data/zookeeper</value>
    </property>
    <property>
        <name>hbase.unsafe.stream.capability.enforce</name>
        <value>false</value>
    </property>
    <property>
        <name>hbase.tmp.dir</name>
        <value>${HADOOP_HOME}/hdfs/data/hbase-tmp</value>
    </property>
</configuration>
EOL
cat > $HBASE_HOME/conf/hbase-env.sh   << EOL
export JAVA_HOME=/usr/lib/jvm/jre
export HBASE_MANAGES_ZK=true
export HBASE_PID_DIR=$HADOOP_HOME/hdfs/data/hbase-pid
export HBASE_LOG_DIR=$HADOOP_HOME/hdfs/data/hbase-logs
EOL

$HBASE_HOME/bin/start-hbase.sh
jps
### 完整启动：
$HADOOP_HOME/sbin/start-dfs.sh
$HADOOP_HOME/sbin/start-yarn.sh
$HBASE_HOME/bin/start-hbase.sh
jps
### 完整停止：
$HBASE_HOME/bin/stop-hbase.sh
$HADOOP_HOME/sbin/stop-yarn.sh
$HADOOP_HOME/sbin/stop-dfs.sh
