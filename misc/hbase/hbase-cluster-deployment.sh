#!/bin/bash 

# 所有节点先进行操作系统优化
# 参考 benchmark/os-optimization.sh 

######################################################################################################
# node1/2/3 操作：3个实例挂载磁盘
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

WORK_DIR=/mnt/nvme1n1
echo "export WORK_DIR=$WORK_DIR" >> ~/.bashrc
source ~/.bashrc
mkdir -p $WORK_DIR
chmod 777 -R $WORK_DIR

# 将3个节点主机名写入 /etc/hosts 文件 <==== 在这里填写节点的IP地址
IPADDR_NODE1="172.31.36.18"
IPADDR_NODE2="172.31.38.32"
IPADDR_NODE3="172.31.43.55"

sudo cat >> /etc/hosts << EOF
$IPADDR_NODE1 node1
$IPADDR_NODE2 node2
$IPADDR_NODE3 node3
EOF

# 安装基础软件
sudo yum install -y java-11-amazon-corretto-devel python3-pip iotop htop
sudo pip3 install dool

# 退出root用户
exit

######################################################################################################
# 配置 3 节点的无密码登录
# 回到了 ec2-user 用户

WORK_DIR=/mnt/nvme1n1
echo "export WORK_DIR=$WORK_DIR" >> ~/.bashrc
source ~/.bashrc

# node1/2/3：生成密钥用于无密码登录：
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
chmod 0600 ~/.ssh/authorized_keys
cat ~/.ssh/id_rsa.pub 

vim ~/.ssh/authorized_keys
### 将 node1/2/3  节点的【cat ~/.ssh/id_rsa.pub】输出结果添加到所有节点的 authorized_keys 文件

# 在 node1/2/3 分别验证无密码登录
ssh node1 hostname
ssh node2 hostname 
ssh node3 hostname

######################################################################################################
# 在 node-1 安装和配置 Hadoop 软件
# 设置软件栈版本：
HADOOP_VERSION=3.3.5
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
mv hadoop-$HADOOP_VERSION hadoop

cat >> ~/.bashrc << EOF
export HADOOP_HOME=${WORK_DIR}/hadoop
export JAVA_HOME=/usr/lib/jvm/jre
export PATH=$HADOOP_HOME/sbin:$HADOOP_HOME/bin:$PATH
EOF
source ~/.bashrc

mkdir $HADOOP_HOME/tmp
mkdir $HADOOP_HOME/hdfs
mkdir $HADOOP_HOME/hdfs/name
mkdir $HADOOP_HOME/hdfs/data
$HADOOP_HOME/bin/hadoop version

# 修改 Hadoop-env.sh 脚本：
JAVA_HOME="/usr/lib/jvm/jre"
echo "export JAVA_HOME=${JAVA_HOME}" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh

# 修改 core-site.xml 配置文件：
cat << EOF > $HADOOP_HOME/etc/hadoop/core-site.xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://node1:9000</value>
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
        <value>2</value>
    </property>
    <property>
        <name>dfs.name.dir</name>
        <value>${HADOOP_HOME}/hdfs/name</value>
    </property>
    <property>
        <name>dfs.data.dir</name>
        <value>${HADOOP_HOME}/hdfs/data</value>
    </property>
    <property>
        <name>dfs.namenode.secondary.http-address</name>
        <value>node1:50090</value>
    </property>
</configuration>
EOF

# 修改 yarn-site.xml 配置文件：
cat << EOF > $HADOOP_HOME/etc/hadoop/yarn-site.xml
<?xml version="1.0"?>
<configuration>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>node1</value>
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

# 修改 workers 文件
cat << EOF > $HADOOP_HOME/etc/hadoop/workers
node1
node2
node3
EOF

# 将配置好的hadoop 软件包传输到 node2 和 node3 节点
scp -rq $HADOOP_HOME node2:$WORK_DIR
scp -rq $HADOOP_HOME node3:$WORK_DIR

# node1初始化 HDFS 节点，启动 DFS 和 Yarn：
$HADOOP_HOME/bin/hdfs namenode -format
$HADOOP_HOME/sbin/start-dfs.sh
$HADOOP_HOME/sbin/start-yarn.sh
jps

######################################################################################################
# 节点 1 安装 zookeeper
cd $WORK_DIR
wget https://archive.apache.org/dist/zookeeper/zookeeper-3.8.0/apache-zookeeper-3.8.0-bin.tar.gz
tar zxf apache-zookeeper-3.8.0-bin.tar.gz
mv apache-zookeeper-3.8.0-bin zookeeper
mkdir -p $WORK_DIR/zookeeper/data/{tmp,log}
cd zookeeper/conf
cp zoo_sample.cfg zoo.cfg
sed -i "s|dataDir=.*|dataDir=$WORK_DIR/zookeeper/data/tmp|g" zoo.cfg
sed -i "s|clientPort=.*|clientPort=2181|g" zoo.cfg
echo "dataLogDir=$WORK_DIR/zookeeper/data/log" >> zoo.cfg
echo "server.1=node1:2888:3888" >> zoo.cfg
echo "server.2=node2:2888:3888" >> zoo.cfg
echo "server.3=node3:2888:3888" >> zoo.cfg
diff zoo.cfg zoo_sample.cfg

# 传到 node2/3 节点
scp -rq $WORK_DIR/zookeeper node2:$WORK_DIR
scp -rq $WORK_DIR/zookeeper node3:$WORK_DIR

# 创建 myid 文件
ssh node1 "echo 1 > $WORK_DIR/zookeeper/data/tmp/myid"
ssh node2 "echo 2 > $WORK_DIR/zookeeper/data/tmp/myid"
ssh node3 "echo 3 > $WORK_DIR/zookeeper/data/tmp/myid"

# 启动 zookeeper
ssh node1 "$WORK_DIR/zookeeper/bin/zkServer.sh start"
ssh node2 "$WORK_DIR/zookeeper/bin/zkServer.sh start"
ssh node3 "$WORK_DIR/zookeeper/bin/zkServer.sh start"
# 查看状态
ssh node1 "$WORK_DIR/zookeeper/bin/zkServer.sh status"
ssh node2 "$WORK_DIR/zookeeper/bin/zkServer.sh status"
ssh node3 "$WORK_DIR/zookeeper/bin/zkServer.sh status"
# 停止 zookeeper
ssh node1 "$WORK_DIR/zookeeper/bin/zkServer.sh stop"
ssh node2 "$WORK_DIR/zookeeper/bin/zkServer.sh stop"
ssh node3 "$WORK_DIR/zookeeper/bin/zkServer.sh stop"


######################################################################################################
## 安装 Hbase
cd $WORK_DIR

# wget https://archive.apache.org/dist/hbase/2.3.6/hbase-2.3.6-bin.tar.gz
# tar zxf hbase-2.3.6-bin.tar.gz
# mv hbase-2.3.6 hbase

HBASE_VERSION=2.5.11
wget https://downloads.apache.org/hbase/$HBASE_VERSION/hbase-$HBASE_VERSION-hadoop3-bin.tar.gz
tar zxf hbase-${HBASE_VERSION}-hadoop3-bin.tar.gz
mv hbase-${HBASE_VERSION}-hadoop3 hbase

echo "export HBASE_HOME=${WORK_DIR}/hbase" >> ~/.bashrc
source  ~/.bashrc

mkdir -p $HBASE_HOME/{zookeeper,hbase-tmp,hbase-pid,hbase-logs}

cat >> $HBASE_HOME/conf/hbase-env.sh << EOF
export JAVA_HOME=/usr/lib/jvm/jre
export HBASE_MANAGES_ZK=false
export HBASE_PID_DIR=$HBASE_HOME/hbase-pid
export HBASE_LOG_DIR=$HBASE_HOME/hbase-logs
export HBASE_DISABLE_HADOOP_CLASSPATH_LOOKUP="true"
EOF

## 下面的 hbase-site.xml 配置是根据 16c128g size 进行优化
cat > $HBASE_HOME/conf/hbase-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>hbase.cluster.distributed</name>
        <value>true</value>
    </property>
    <property>
        <name>hbase.rootdir</name>
        <value>hdfs://node1:9000/hbase</value>
    </property>
    <property>
        <name>hbase.tmp.dir</name>
        <value>/mnt/nvme1n1/hadoop/hdfs/data/hbase-tmp</value>
    </property>
    <property>
        <name>hbase.unsafe.stream.capability.enforce</name>
        <value>false</value>
    </property>
    <property>
        <name>hbase.zookeeper.quorum</name>
        <value>node1,node2,node3</value>
    </property>
    <property>
        <name>hbase.zookeeper.property.clientPort</name>
        <value>2181</value>
    </property>
    <property>
        <name>zookeeper.znode.parent</name>
        <value>/hbase</value>
    </property>
    <property>
        <name>hbase.regionserver.handler.count</name>
        <value>128</value>        <!-- 默认为30，可根据CPU核心数增加，如CPU核心数×2 -->
    </property>

    <!-- 内存配置 -->
    <property>
        <name>hbase.regionserver.global.memstore.size</name>
        <value>0.4</value>
        <description>RegionServer中所有memstore使用的堆内存比例，调高以提升写性能</description>
    </property>

    <property>
        <name>hbase.regionserver.global.memstore.size.lower.limit</name>
        <value>0.38</value>
        <description>触发memstore刷新的下限</description>
    </property>

    <property>
        <name>hbase.hregion.memstore.flush.size</name>
        <value>268435456</value>
        <description>单个memstore刷新阈值，设为256MB</description>
    </property>

    <property>
        <name>hbase.regionserver.maxlogs</name>
        <value>64</value>
        <description>单个RegionServer上允许的最大WAL文件数</description>
    </property>

    <property>
        <name>hbase.regionserver.hlog.blocksize</name>
        <value>268435456</value>
        <description>WAL文件块大小，设为256MB</description>
    </property>

    <property>
        <name>hbase.hregion.max.filesize</name>
        <value>10737418240</value>
        <description>Region分裂阈值，设为10GB</description>
    </property>

    <!-- 缓存配置 -->
    <property>
        <name>hfile.block.cache.size</name>
        <value>0.4</value>
        <description>BlockCache占用的堆内存比例，提高读性能</description>
    </property>

    <property>
        <name>hbase.bucketcache.size</name>
        <value>10240</value>
        <description>堆外缓存大小</description>
    </property>

    <property>
        <name>hbase.bucketcache.ioengine</name>
        <value>offheap</value>
        <description>使用堆外内存作为二级缓存</description>
    </property>

    <property>
        <name>hbase.rs.cacheblocksonwrite</name>
        <value>true</value>
        <description>写入时缓存数据块</description>
    </property>

    <!-- RPC 连接池优化 -->
    <property>
        <name>hbase.client.ipc.pool.size</name>
        <value>10</value>
        <description>客户端 RPC 连接池大小，增加并发连接数</description>
    </property>

    <property>
        <name>hbase.client.ipc.pool.type</name>
        <value>RoundRobinPool</value>
        <description>连接池类型，使用轮询方式分配连接</description>
    </property>

    <property>
        <name>hbase.client.max.perserver.tasks</name>
        <value>20</value>
        <description>每个服务器允许的最大并发任务数</description>
    </property>

    <!-- 网络缓冲区设置 -->
    <property>
        <name>hbase.ipc.server.tcpnodelay</name>
        <value>true</value>
        <description>禁用 Nagle 算法，减少小数据包的延迟</description>
    </property>

    <!-- 批量操作优化 -->
    <property>
        <name>hbase.client.write.buffer</name>
        <value>8388608</value>
        <description>客户端写缓冲区大小，设为 8MB，提高批量写入性能</description>
    </property>
</configuration>  
EOF

cat > $HBASE_HOME/conf/regionservers << EOF
node1
node2
node3
EOF

# 传到 node2/3 节点
scp -rq $HBASE_HOME node2:$WORK_DIR
scp -rq $HBASE_HOME node3:$WORK_DIR 

# 启动 Hbase
$HBASE_HOME/bin/start-hbase.sh
# 查看状态
ssh node1 "jps"
ssh node2 "jps"
ssh node3 "jps"

# 验证 Hbase 是否正常运行，在 3 个节点通过 dool 查看资源利用率
$HBASE_HOME/bin/hbase pe --nomapred --oneCon=true --valueSize=100 --rows=150000 --autoFlush=true --presplit=8 randomWrite 8



######################################################################################################
### Reference
# https://www.hangge.com/blog/cache/detail_3435.html
# https://community.cloudera.com/t5/Community-Articles/Tuning-Hbase-for-optimized-performance-Part-1/ta-p/248137


# Freewheel 测试集群配置
# 服务版本：Hadoop 3.3.2 + HBase 2.3.6
# Intel集群：2 * m5.xlarge Master + 3 * i4i.4xlarge RegionServer + JDK 8
# ARM集群：2 * m8g.xlarge Master + 3 * i8g.4xlarge RegionServer + JDK 11