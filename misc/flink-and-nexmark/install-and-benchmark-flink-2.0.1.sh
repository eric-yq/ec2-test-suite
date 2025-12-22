#!/bin/bash

# Reference: https://aws.amazon.com/cn/blogs/china/aws-graviton3-accelerates-flink-job-execution-benchmark/
# for Amazon Linux 2023，使用 ec2-user 用户登录执行

# 部署 Flink Standalone 集群环境
#####################################################################
## 通过 SSH 登录到 3 台 EC2 实例，分别执行下面命令，安装必要的基础软件
#####################################################################
## 生成密钥
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
chmod 0600 ~/.ssh/authorized_keys
## 安装 JDK
sudo yum install -y java-17-amazon-corretto java-17-amazon-corretto-devel git htop screen python3-pip
sudo pip3 install dool
echo "export JAVA_HOME=$(ls -d /usr/lib/jvm/java)" >> ~/.bash_profile
echo "export FLINK_HOME=~/flink-benchmark/flink" >> ~/.bash_profile
source ~/.bash_profile
java -version

## 安装 maven
cd ~
# wget https://archive.apache.org/dist/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.tar.gz
wget https://mirrors.aliyun.com/apache/maven/maven-3/3.9.11/binaries/apache-maven-3.9.11-bin.tar.gz
tar zxf apache-maven-3.9.11-bin.tar.gz
echo "export PATH=$PATH:~/apache-maven-3.9.11/bin" >> ~/.bashrc
source ~/.bashrc
mvn -v

# for 阿里云国内：
# wget https://mirrors.aliyun.com/apache/maven/maven-3/3.9.11/binaries/apache-maven-3.9.11-bin.tar.gz

## 将 下列 3 个 IPADDR_xxx 变量设置为 3 台 EC2 实例的 VPC IP 地址，并保存在 /etc/hosts 文件中
IPADDR_MASTER="172.31.38.136"
IPADDR_WORKER1="172.31.39.174"
IPADDR_WORKER2="172.31.35.45"
cat << EOF | sudo tee -a /etc/hosts
$IPADDR_MASTER  master
$IPADDR_WORKER1 worker1
$IPADDR_WORKER2 worker2
EOF
cd ~/.ssh && cat id_rsa.pub 
### 将 master 和 worker1,2 节点的【cat ~/.ssh/id_rsa.pub】 的输出结果
### 添加到所有节点的 authorized_keys 文件
vim authorized_keys
### 保存退出

#####################################################################
## 在 Master 节点继续执行下面操作：完成 Flink 和 Nexmark 安装与配置。
#####################################################################
## 下载和解压缩 Flink 软件包：
mkdir ~/flink-benchmark
cd ~/flink-benchmark
version="2.0.1"
# wget https://dlcdn.apache.org/flink/flink-$version/flink-$version-bin-scala_2.12.tgz
wget https://mirrors.aliyun.com/apache/flink/flink-$version/flink-$version-bin-scala_2.12.tgz
tar zxf flink-$version-bin-scala_2.12.tgz && mv flink-$version flink

## 配置 masters 和 workers 文件
echo master:8081 > flink/conf/masters
echo worker1 >> flink/conf/workers
echo worker2 >> flink/conf/workers

## 下载 Nexmark 源码并完成构建, 使用 nexmark 在 20240415 之前的那个 commit
cd ~/flink-benchmark && git clone https://github.com/nexmark/nexmark.git
# cd nexmark
# git checkout b5e45d762f38f1c67e59bd73c02f15933a750d70
# cd ..
mv nexmark nexmark-src && cd nexmark-src/nexmark-flink
sed -i.bak "s/2.0-preview1/$version/g" ../pom.xml
./build.sh
mv nexmark-flink.tgz ~/flink-benchmark
cd ~/flink-benchmark && tar xzf nexmark-flink.tgz
cp ~/flink-benchmark/nexmark-flink/lib/*.jar ~/flink-benchmark/flink/lib

## 编辑 Nexmark 配置文件 nexmark-flink/conf/config.yaml
CPU_CORES=$(nproc)
MEM_TOTAL_GB=$(free -g |grep Mem | awk -F " " '{print $2}')
let XXX=${MEM_TOTAL_GB}*75/100
sed -i "s/jobmanager.rpc.address: localhost/jobmanager.rpc.address: master/g" nexmark-flink/conf/config.yaml
sed -i "s/taskmanager.numberOfTaskSlots: 1/taskmanager.numberOfTaskSlots: ${CPU_CORES}/g" nexmark-flink/conf/config.yaml
sed -i "s/taskmanager.memory.process.size: 8G/taskmanager.memory.process.size: ${XXX}G/g" nexmark-flink/conf/config.yaml
sed -i "s/parallelism.default: 8/parallelism.default: 24/g" nexmark-flink/conf/config.yaml
sed -i "s/file:\/\/\/path\/to\/checkpoint/file:\/\/\/home\/ec2-user\/checkpoint/g" nexmark-flink/conf/config.yaml
sed -i "s/-XX:ParallelGCThreads=4/-XX:ParallelGCThreads=4 -XX:+IgnoreUnrecognizedVMOptions/g" nexmark-flink/conf/config.yaml
mv ~/flink-benchmark/flink/conf/config.yaml ~/flink-benchmark/flink/conf/config.yaml.bak
cp -f nexmark-flink/conf/config.yaml flink/conf/
# cp -f nexmark-flink/conf/sql-client-defaults.yaml flink/conf/

## 编辑 Nexmark 配置文件 nexmark-flink/conf/nexmark.yaml
sed -i "s/nexmark.metric.reporter.host: localhost/nexmark.metric.reporter.host: master/g" nexmark-flink/conf/nexmark.yaml
sed -i "s/#nexmark.metric.monitor.delay: 3min/nexmark.metric.monitor.delay: 3s/g" nexmark-flink/conf/nexmark.yaml

## 将 master 节点已安装的软件包通过 scp 命令传输到 worker1/2 节点
scp -r ~/flink-benchmark ec2-user@worker1:~/
scp -r ~/flink-benchmark ec2-user@worker2:~/

# 启动 Flink Standalone 集群
#####################################################################
## 在 Master 节点继续执行下面操作
#####################################################################
bash ~/flink-benchmark/flink/bin/start-cluster.sh
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
bash ~/flink-benchmark/flink/bin/stop-cluster.sh

