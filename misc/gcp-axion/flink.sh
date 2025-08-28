#!/bin/bash

# Reference: https://aws.amazon.com/cn/blogs/china/aws-graviton3-accelerates-flink-job-execution-benchmark/

# Ubuntu 24.04 LTS

# 部署 Flink Standalone 集群环境
############################################################################
## 通过 SSH 登录到 3 台 EC2 实例，分别执行下面命令：配置免密登录，和，安装必要的基础软件
############################################################################
## 配置免密登录
sudo su - root
sed -i.bak "s/PermitRootLogin no/PermitRootLogin yes/g" /etc/ssh/sshd_config 
systemctl restart ssh

## 生成密钥
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub 

### 将 master 和 worker1,2 节点的【cat ~/.ssh/id_rsa.pub】 的输出结果
### 添加到所有节点的 authorized_keys 文件
vim ~/.ssh/authorized_keys
### 保存退出
chmod 0600 ~/.ssh/authorized_keys

## 将 下列 3 个 IPADDR_xxx 变量设置为 3 台 EC2 实例的 VPC IP 地址，并保存在 /etc/hosts 文件中
IPADDR_MASTER="10.138.0.7"
IPADDR_WORKER1="10.138.0.8"
IPADDR_WORKER2="10.138.0.79"
cat << EOF >> /etc/hosts
$IPADDR_MASTER  master
$IPADDR_WORKER1 worker1
$IPADDR_WORKER2 worker2
EOF

## 安装 JDK
# for centos stream 9
# yum install -y epel-release
# yum update -y
# yum install -y wget zip unzip screen htop git
# rpm --import https://yum.corretto.aws/corretto.key 
# curl -L -o /etc/yum.repos.d/corretto.repo https://yum.corretto.aws/corretto.repo
# yum install -y java-1.8.0-amazon-corretto-devel

# for ubuntu 24.04
apt update -y
apt install -y wget zip unzip screen htop git
wget -O- https://apt.corretto.aws/corretto.key | sudo apt-key add - 
add-apt-repository 'deb https://apt.corretto.aws stable main' -y
apt update -y
apt install -y java-1.8.0-amazon-corretto-jdk
java -version

## 安装 maven
cd /root/
wget https://archive.apache.org/dist/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.tar.gz
tar zxf apache-maven-3.9.6-bin.tar.gz
echo "export PATH=$PATH:/root/apache-maven-3.9.6/bin" >> ~/.bashrc
source /root/.bashrc
mvn -v

## 设置环境变量
echo "export FLINK_HOME=/root/flink-benchmark/flink-1.17.2" >> ~/.profile
source /root/.profile

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
cd /root/flink-benchmark && git clone https://github.com/nexmark/nexmark.git
cd nexmark && git checkout b5e45d762f38f1c67e59bd73c02f15933a750d70
cd .. && mv nexmark nexmark-src
cd nexmark-src/nexmark-flink && ./build.sh
mv nexmark-flink.tgz /root/flink-benchmark
cd /root/flink-benchmark && tar xzf nexmark-flink.tgz
cp -f /root/flink-benchmark/nexmark-flink/lib/*.jar /root/flink-benchmark/flink-1.17.2/lib/
# cp -f /root/flink-benchmark/flink-1.17.2/lib/* /root/flink-benchmark/nexmark-flink/lib/

## 编辑 Nexmark 配置文件 nexmark-flink/conf/flink-conf.yaml
sed -i "s/jobmanager.rpc.address: localhost/jobmanager.rpc.address: master/g" nexmark-flink/conf/flink-conf.yaml
sed -i "s/taskmanager.numberOfTaskSlots: 1/taskmanager.numberOfTaskSlots: 8/g" nexmark-flink/conf/flink-conf.yaml
sed -i "s/taskmanager.memory.process.size: 8G/taskmanager.memory.process.size: 48G/g" nexmark-flink/conf/flink-conf.yaml
sed -i "s/parallelism.default: 8/parallelism.default: 24/g" nexmark-flink/conf/flink-conf.yaml
sed -i "s/file:\/\/\/path\/to\/checkpoint/file:\/\/\/root\/checkpoint/g" nexmark-flink/conf/flink-conf.yaml
sed -i "s/-XX:ParallelGCThreads=4/-XX:ParallelGCThreads=4 -XX:+IgnoreUnrecognizedVMOptions/g" nexmark-flink/conf/flink-conf.yaml
ll flink-1.17.2/conf/flink-conf.yaml
mv flink-1.17.2/conf/flink-conf.yaml flink-1.17.2/conf/flink-conf.yaml.bak
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
# 先单独执行一个 q0，看看效果
# bash ~/flink-benchmark/nexmark-flink/bin/run_query.sh q0
# 再执行所有查询
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
# Result Summary: 
# flink-master	us-central1-a	8月 27, 2025, 6:28:46 下午	c4a-highmem-8	Spot（抢占）	10.128.0.11 (nic0)	34.68.181.202 (nic0) 	
# flink-worker1	us-central1-a	8月 27, 2025, 6:29:17 下午	c4a-highmem-8	Spot（抢占）	10.128.0.12 (nic0)	34.56.13.176 (nic0) 	
# flink-worker2	us-central1-a	8月 27, 2025, 6:29:49 下午	c4a-highmem-8	Spot（抢占）	10.128.0.13 (nic0)	34.70.108.247 (nic0) 

## centos stream 9
# -------------------------------- Nexmark Results --------------------------------
# | Nexmark Query     | Events Num        | Cores             | Time(s)           | Cores * Time(s)   | Throughput/Cores  |
# +-------------------+-------------------+-------------------+-------------------+-------------------+-------------------+
# |q0                 |100,000,000        |22.17              |14.343             |318.048            |314.42 K/s  
# |q1                 |100,000,000        |23.8               |14.442             |343.748            |290.91 K/s  
# |q2                 |100,000,000        |23.49              |13.303             |312.429            |320.07 K/s   
# |q3                 |100,000,000        |�                  |24.870             |NaN                |0/s 
# |q4                 |100,000,000        |19.4               |142.691            |2768.265           |36.12 K/s   
# |q5                 |100,000,000        |13.99              |113.633            |1590.097           |62.89 K/s    
# |q7                 |100,000,000        |21.05              |198.270            |4173.096           |23.96 K/s          |
# |q8                 |100,000,000        |�                  |24.447             |NaN                |0/s                |
# |q9                 |100,000,000        |17.52              |190.602            |3339.378           |29.95 K/s          |
# |q10                |100,000,000        |15.23              |107.614            |1638.864           |61.02 K/s          |
# |q11                |100,000,000        |22.47              |123.062            |2765.745           |36.16 K/s          |
# |q12                |100,000,000        |22.44              |36.428             |817.364            |122.34 K/s         |
# |q13                |100,000,000        |�                  |24.545             |NaN                |0/s                |
# |q14                |100,000,000        |�                  |18.457             |NaN                |0/s                |
# |q15                |100,000,000        |23.05              |57.569             |1326.806           |75.37 K/s          |
# |q16                |100,000,000        |20.17              |291.834            |5887.562           |16.98 K/s          |
# |q17                |100,000,000        |21.11              |37.062             |782.421            |127.81 K/s         |
# |q18                |100,000,000        |18.7               |83.175             |1555.522           |64.29 K/s          |
# |q19                |100,000,000        |19.4               |109.832            |2130.754           |46.93 K/s          |
# |q20                |100,000,000        |20.33              |228.474            |4645.488           |21.53 K/s          |
# |q21                |100,000,000        |22.04              |43.072             |949.376            |105.33 K/s         |
# |q22                |100,000,000        |�                  |32.460             |NaN                |0/s                |

## ubuntu 24.04： 测试 1，逐个执行 sql
# -------------------------------- Nexmark Results --------------------------------
# | Nexmark Query     | Events Num        | Cores             | Time(s)           | Cores * Time(s)   | Throughput/Cores  |
# +-------------------+-------------------+-------------------+-------------------+-------------------+-------------------+
# |q0                 |100,000,000        |�                  |18.660             |NaN                |0/s                |
# |q1                 |100,000,000        |�                  |19.760             |NaN                |0/s                |
# |q2                 |100,000,000        |�                  |17.065             |NaN                |0/s                |
# |q3                 |100,000,000        |23.58              |28.900             |681.398            |146.76 K/s         |
# |q4                 |100,000,000        |19.99              |143.276            |2864.730           |34.91 K/s          |
# |q5                 |100,000,000        |13.62              |124.941            |1701.958           |58.76 K/s          |
# |q7                 |100,000,000        |20.41              |208.342            |4251.228           |23.52 K/s          |
# |q8                 |100,000,000        |23.67              |29.244             |692.203            |144.47 K/s         |
# |q9                 |100,000,000        |19.66              |326.414            |6417.045           |15.58 K/s          |
# |q10                |100,000,000        |18.9               |101.360            |1915.374           |52.21 K/s          |
# |q11                |100,000,000        |22.95              |129.904            |2980.812           |33.55 K/s          |
# |q12                |100,000,000        |21.39              |42.138             |901.186            |110.96 K/s         |
# |q13                |100,000,000        |23.67              |28.925             |684.729            |146.04 K/s         |
# |q14                |100,000,000        |�                  |23.525             |NaN                |0/s                |
# |q15                |100,000,000        |21.65              |64.704             |1400.762           |71.39 K/s          |
# |q16                |100,000,000        |20.52              |308.251            |6324.847           |15.81 K/s          |
# |q17                |100,000,000        |18.62              |42.084             |783.664            |127.61 K/s         |
# |q18                |100,000,000        |20.24              |91.588             |1853.795           |53.94 K/s          |
# |q19                |100,000,000        |19.54              |122.244            |2388.980           |41.86 K/s          |
# |q20                |100,000,000        |21.02              |228.616            |4804.432           |20.81 K/s          |
# |q21                |100,000,000        |23.49              |29.462             |692.176            |144.47 K/s         |
# |q22                |100,000,000        |20.34              |37.041             |753.516            |132.71 K/s         |