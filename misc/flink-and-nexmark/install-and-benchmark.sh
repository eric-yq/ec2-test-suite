#!/bin/bash

# Reference: https://aws.amazon.com/cn/blogs/china/aws-graviton3-accelerates-flink-job-execution-benchmark/

# for Amazon Linux 2023

# 部署 Flink Standalone 集群环境
#####################################################################
## 通过 SSH 登录到 3 台 EC2 实例，分别执行下面命令，安装必要的基础软件
#####################################################################
## 生成密钥
sudo su - root
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
chmod 0600 ~/.ssh/authorized_keys
## 安装 JDK
yum install -y java-1.8.0-amazon-corretto java-1.8.0-amazon-corretto-devel git htop screen 
echo "export JAVA_HOME=$(ls -d /usr/lib/jvm/java)" >> ~/.bashrc
echo "export FLINK_HOME=/root/flink-benchmark/flink-1.17.2" >> ~/.bashrc
source /root/.bashrc
java -version

## 安装 maven
cd /root/
wget https://archive.apache.org/dist/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.tar.gz
tar zxf apache-maven-3.9.6-bin.tar.gz
echo "export PATH=$PATH:/root/apache-maven-3.9.6/bin" >> ~/.bashrc
source /root/.bashrc
mvn -v

## 将 下列 3 个 IPADDR_xxx 变量设置为 3 台 EC2 实例的 VPC IP 地址，并保存在 /etc/hosts 文件中
IPADDR_MASTER="172.31.37.225"
IPADDR_WORKER1="172.31.39.81"
IPADDR_WORKER2="172.31.43.57"
cat << EOF >> /etc/hosts
$IPADDR_MASTER  master
$IPADDR_WORKER1 worker1
$IPADDR_WORKER2 worker2
EOF
cd .ssh
cat id_rsa.pub 
### 将 master 和 worker1,2 节点的【cat ~/.ssh/id_rsa.pub】 的输出结果
### 添加到所有节点的 authorized_keys 文件
vim authorized_keys
### 保存退出

#####################################################################
## 在 Master 节点继续执行下面操作：完成 Flink 和 Nexmark 安装。
#####################################################################
## 下载和解压缩 Flink 软件包：
mkdir /root/flink-benchmark
cd /root/flink-benchmark
wget https://dlcdn.apache.org/flink/flink-1.17.2/flink-1.17.2-bin-scala_2.12.tgz
tar zxf flink-1.17.2-bin-scala_2.12.tgz

## 配置 masters 和 workers 文件
echo master:8081 > flink-1.17.2/conf/masters
echo worker1 >> flink-1.17.2/conf/workers
echo worker2 >> flink-1.17.2/conf/workers

## 下载 Nexmark 源码并完成构建, 使用 nexmark 在 20240415 之前的那个 commit
cd /root/flink-benchmark
git clone https://github.com/nexmark/nexmark.git
cd nexmark
git checkout b5e45d762f38f1c67e59bd73c02f15933a750d70
cd ..
mv nexmark nexmark-src
cd nexmark-src/nexmark-flink
./build.sh
mv nexmark-flink.tgz /root/flink-benchmark
cd /root/flink-benchmark
tar xzf nexmark-flink.tgz
cp /root/flink-benchmark/nexmark-flink/lib/*.jar /root/flink-benchmark/flink-1.17.2/lib

## 编辑 Nexmark 配置文件 nexmark-flink/conf/flink-conf.yaml
sed -i "s/jobmanager.rpc.address: localhost/jobmanager.rpc.address: master/g" nexmark-flink/conf/flink-conf.yaml
sed -i "s/taskmanager.numberOfTaskSlots: 1/taskmanager.numberOfTaskSlots: 8/g" nexmark-flink/conf/flink-conf.yaml
sed -i "s/taskmanager.memory.process.size: 8G/taskmanager.memory.process.size: 48G/g" nexmark-flink/conf/flink-conf.yaml
sed -i "s/parallelism.default: 8/parallelism.default: 24/g" nexmark-flink/conf/flink-conf.yaml
sed -i "s/file:\/\/\/path\/to\/checkpoint/file:\/\/\/root\/checkpoint/g" nexmark-flink/conf/flink-conf.yaml
sed -i "s/-XX:ParallelGCThreads=4/-XX:ParallelGCThreads=4 -XX:+IgnoreUnrecognizedVMOptions/g" nexmark-flink/conf/flink-conf.yaml
cp -f nexmark-flink/conf/flink-conf.yaml flink-1.17.2/conf/
cp -f nexmark-flink/conf/sql-client-defaults.yaml flink-1.17.2/conf/

## 编辑 Nexmark 配置文件 nexmark-flink/conf/nexmark.yaml
sed -i "s/nexmark.metric.reporter.host: localhost/nexmark.metric.reporter.host: master/g" nexmark-flink/conf/nexmark.yaml

## 将 master 节点已安装的软件包通过 scp 命令传输到 worker1/2 节点
scp -r ~/flink-benchmark root@worker1:~/
scp -r ~/flink-benchmark root@worker2:~/

# 启动 Flink Standalone 集群
#####################################################################
## 在 Master 节点继续执行下面操作
#####################################################################
bash ~/flink-benchmark/flink-1.17.2/bin/start-cluster.sh
bash ~/flink-benchmark/nexmark-flink/bin/setup_cluster.sh

# 开始执行 Benchmark
#####################################################################
## 在 Master 节点继续执行下面操作
#####################################################################
## 方法 1: 运行 benchmark 的所有 SQL
cd ~
screen -R ttt -L
bash ~/flink-benchmark/nexmark-flink/bin/run_query.sh all

## 方法 2: 执行单独的 SQL， q6 有问题无法执行
for i in `seq 0 22` 
do
    bash ~/flink-benchmark/nexmark-flink/bin/run_query.sh q$i
    sleep 5
done

## 查看日志
grep "Start to run query"  screenlog.0
grep "Stop job query"      screenlog.0
grep "Exception in thread" screenlog.0
grep "Summary Average:"    screenlog.0

grep -E "query|Exception|Summary" screenlog.0 
 
## 停止集群 和 benchmark
bash ~/flink-benchmark/nexmark-flink/bin/shutdown_cluster.sh
bash ~/flink-benchmark/flink-1.17.2/bin/stop-cluster.sh


########################################################################################
# Result Summary: r8i.4xlarge 
# -------------------------------- Nexmark Results --------------------------------

# +-------------------+-------------------+-------------------+-------------------+-------------------+-------------------+
# | Nexmark Query     | Events Num        | Cores             | Time(s)           | Cores * Time(s)   | Throughput/Cores  |
# +-------------------+-------------------+-------------------+-------------------+-------------------+-------------------+
# |q0                 |100,000,000        |23.83              |11.467             |273.222            |366 K/s            |
# |q1                 |100,000,000        |23.58              |12.059             |284.370            |351.65 K/s         |
# |q2                 |100,000,000        |23.78              |11.234             |267.189            |374.27 K/s         |
# |q3                 |100,000,000        |23.54              |17.197             |404.846            |247.01 K/s         |
# |q4                 |100,000,000        |21.3               |80.563             |1716.327           |58.26 K/s          |
# |q5                 |100,000,000        |14.52              |64.491             |936.672            |106.76 K/s         |
# |q7                 |100,000,000        |21.19              |114.857            |2433.897           |41.09 K/s          |
# |q8                 |100,000,000        |21.63              |17.924             |387.779            |257.88 K/s         |
# |q9                 |100,000,000        |20.97              |152.657            |3201.324           |31.24 K/s          |
# |q10                |100,000,000        |15.59              |47.862             |746.334            |133.99 K/s         |
# |q11                |100,000,000        |22                 |80.787             |1777.057           |56.27 K/s          |
# |q12                |100,000,000        |23.51              |24.875             |584.736            |171.02 K/s         |
# |q13                |100,000,000        |23.37              |19.006             |444.146            |225.15 K/s         |
# |q14                |100,000,000        |23.5               |15.392             |361.719            |276.46 K/s         |
# |q15                |100,000,000        |23.46              |39.210             |919.776            |108.72 K/s         |
# |q16                |100,000,000        |19.71              |186.952            |3684.513           |27.14 K/s          |
# |q17                |100,000,000        |22.18              |24.010             |532.442            |187.81 K/s         |
# |q18                |100,000,000        |19.95              |52.419             |1045.910           |95.61 K/s          |
# |q19                |100,000,000        |22.22              |51.434             |1143.075           |87.48 K/s          |
# |q20                |100,000,000        |20.12              |120.864            |2431.374           |41.13 K/s          |
# |q21                |100,000,000        |22.89              |27.300             |624.831            |160.04 K/s         |
# |q22                |100,000,000        |22.32              |21.647             |483.162            |206.97 K/s         |
# |Total              |2,200,000,000      |475.168            |1194.207           |24684.702          |3.61 M/s           |
# +-------------------+-------------------+-------------------+-------------------+-------------------+-------------------+