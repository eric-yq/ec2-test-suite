#!/bin/bash

# 部署 Flink Standalone 集群环境
#####################################################################
## 通过 SSH 登录到 3 台 EC2 实例，分别执行下面命令，安装必要的基础软件
#####################################################################
## 生成密钥
sudo su - root
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
chmod 0600 ~/.ssh/authorized_keys
## 安装 JDK
yum install -y java-1.8.0-alibaba-dragonwell java-1.8.0-alibaba-dragonwell-devel \
               git htop screen 
echo "export JAVA_HOME=$(ls -d /usr/lib/jvm/java)" >> ~/.bash_profile
echo "export FLINK_HOME=/root/flink-benchmark/flink-1.17.2" >> ~/.bash_profile
source ~/.bash_profile
java -version

## 安装 maven
cd /root/
wget http://mirrors.cloud.aliyuncs.com/apache/maven/maven-3/3.9.11/binaries/apache-maven-3.9.11-bin.tar.gz
tar zxf apache-maven-3.9.11-bin.tar.gz
echo "export PATH=$PATH:/root/apache-maven-3.9.11/bin" >> ~/.bashrc
source /root/.bashrc
mvn -v
mkdir -p /root/.m2
vi /root/.m2/settings.xml
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

## 将 下列 3 个 IPADDR_xxx 变量设置为 3 台 EC2 实例的 VPC IP 地址，并保存在 /etc/hosts 文件中
IPADDR_MASTER="172.24.133.65"
IPADDR_WORKER1="172.24.133.66"
IPADDR_WORKER2="172.24.133.67"
cat << EOF >> /etc/hosts
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
## 在 Master 节点继续执行下面操作：完成 Flink 和 Nexmark 安装。
#####################################################################
## 下载和解压缩 Flink 软件包：
mkdir /root/flink-benchmark
cd /root/flink-benchmark
wget http://mirrors.cloud.aliyuncs.com/apache/flink/flink-1.17.2/flink-1.17.2-bin-scala_2.12.tgz
tar zxf flink-1.17.2-bin-scala_2.12.tgz

## 配置 masters 和 workers 文件
echo master:8081 > flink-1.17.2/conf/masters
echo worker1 >> flink-1.17.2/conf/workers
echo worker2 >> flink-1.17.2/conf/workers

## 下载 Nexmark 源码并完成构建, 使用 nexmark 在 20240415 之前的那个 commit
cd /root/flink-benchmark && git clone https://github.com/nexmark/nexmark.git
cd nexmark && git checkout b5e45d762f38f1c67e59bd73c02f15933a750d70
cd .. && mv nexmark nexmark-src && cd nexmark-src/nexmark-flink
./build.sh
mv nexmark-flink.tgz /root/flink-benchmark
cd /root/flink-benchmark && tar xzf nexmark-flink.tgz
cp /root/flink-benchmark/nexmark-flink/lib/*.jar /root/flink-benchmark/flink-1.17.2/lib

## 编辑 Nexmark 配置文件 nexmark-flink/conf/flink-conf.yaml
sed -i "s/jobmanager.rpc.address: localhost/jobmanager.rpc.address: master/g" nexmark-flink/conf/flink-conf.yaml
sed -i "s/taskmanager.numberOfTaskSlots: 1/taskmanager.numberOfTaskSlots: 8/g" nexmark-flink/conf/flink-conf.yaml
sed -i "s/taskmanager.memory.process.size: 8G/taskmanager.memory.process.size: 48G/g" nexmark-flink/conf/flink-conf.yaml
sed -i "s/parallelism.default: 8/parallelism.default: 24/g" nexmark-flink/conf/flink-conf.yaml
sed -i "s/file:\/\/\/path\/to\/checkpoint/file:\/\/\/root\/checkpoint/g" nexmark-flink/conf/flink-conf.yaml
sed -i "s/-XX:ParallelGCThreads=4/-XX:ParallelGCThreads=4 -XX:+IgnoreUnrecognizedVMOptions/g" nexmark-flink/conf/flink-conf.yaml
mv /root/flink-benchmark/flink-1.17.2/conf/flink-conf.yaml /root/flink-benchmark/flink-1.17.2/conf/flink-conf.yaml.bak
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
# Result Summary: ecs.r9i.2xlarge 
# -------------------------------- Nexmark Results --------------------------------
+-------------------+-------------------+-------------------+-------------------+-------------------+-------------------+
| Nexmark Query     | Events Num        | Cores             | Time(s)           | Cores * Time(s)   | Throughput/Cores  |
+-------------------+-------------------+-------------------+-------------------+-------------------+-------------------+
|q0                 |100,000,000        |23.66              |11.952             |282.833            |353.56 K/s         |
|q1                 |100,000,000        |23.71              |12.338             |292.475            |341.91 K/s         |
|q2                 |100,000,000        |23.49              |11.669             |274.065            |364.88 K/s         |
|q3                 |100,000,000        |23.52              |17.718             |416.664            |240 K/s            |
|q4                 |100,000,000        |20.47              |84.756             |1734.713           |57.65 K/s          |
|q5                 |100,000,000        |14.34              |68.987             |989.309            |101.08 K/s         |
|q7                 |100,000,000        |21.36              |117.038            |2500.189           |40 K/s             |
|q8                 |100,000,000        |21.97              |19.154             |420.748            |237.67 K/s         |
|q9                 |100,000,000        |17.57              |182.709            |3211.085           |31.14 K/s          |
|q10                |100,000,000        |14.1               |59.287             |835.679            |119.66 K/s         |
|q11                |100,000,000        |22.22              |84.930             |1887.148           |52.99 K/s          |
|q12                |100,000,000        |22.3               |28.144             |627.516            |159.36 K/s         |
|q13                |100,000,000        |23.7               |19.451             |461.072            |216.89 K/s         |
|q14                |100,000,000        |23.69              |15.371             |364.168            |274.6 K/s          |
|q15                |100,000,000        |23.4               |38.699             |905.729            |110.41 K/s         |
|q16                |100,000,000        |20.07              |180.025            |3613.102           |27.68 K/s          |
|q17                |100,000,000        |22.99              |25.315             |581.927            |171.84 K/s         |
|q18                |100,000,000        |18.91              |54.454             |1029.973           |97.09 K/s          |
|q19                |100,000,000        |21.43              |54.406             |1165.681           |85.79 K/s          |
|q20                |100,000,000        |21.27              |130.680            |2779.119           |35.98 K/s          |
|q21                |100,000,000        |23.49              |28.232             |663.101            |150.81 K/s         |
|q22                |100,000,000        |23.35              |21.501             |501.985            |199.21 K/s         |
|Total              |2,200,000,000      |470.995            |1266.816           |25538.281          |3.47 M/s           |
+-------------------+-------------------+-------------------+-------------------+-------------------+-------------------+

########################################################################################
# Result Summary: ecs.r9a.2xlarge 
# -------------------------------- Nexmark Results --------------------------------
+-------------------+-------------------+-------------------+-------------------+-------------------+-------------------+
| Nexmark Query     | Events Num        | Cores             | Time(s)           | Cores * Time(s)   | Throughput/Cores  |
+-------------------+-------------------+-------------------+-------------------+-------------------+-------------------+
|q0                 |100,000,000        |18.29              |12.401             |226.841            |440.84 K/s         |
|q1                 |100,000,000        |19.1               |11.247             |214.831            |465.48 K/s         |
|q2                 |100,000,000        |17.39              |12.378             |215.249            |464.58 K/s         |
|q3                 |100,000,000        |�                  |19.045             |NaN                |0/s                |
|q4                 |100,000,000        |20.7               |132.064            |2733.448           |36.58 K/s          |
|q5                 |100,000,000        |13.48              |99.458             |1340.646           |74.59 K/s          |
|q7                 |100,000,000        |19.87              |189.293            |3761.163           |26.59 K/s          |
|q8                 |100,000,000        |22.62              |17.935             |405.601            |246.55 K/s         |
|q9                 |100,000,000        |14.75              |294.528            |4344.696           |23.02 K/s          |
|q10                |100,000,000        |11.01              |78.036             |859.421            |116.36 K/s         |
|q11                |100,000,000        |21.82              |120.828            |2636.799           |37.92 K/s          |
|q12                |100,000,000        |19.02              |31.701             |603.104            |165.81 K/s         |
|q13                |100,000,000        |�                  |20.103             |NaN                |0/s                |
|q14                |100,000,000        |23.39              |14.710             |343.998            |290.7 K/s          |
|q15                |100,000,000        |23.43              |54.651             |1280.614           |78.09 K/s          |
|q16                |100,000,000        |19.7               |295.865            |5827.775           |17.16 K/s          |
|q17                |100,000,000        |18.2               |29.896             |544.085            |183.79 K/s         |
|q18                |100,000,000        |19.01              |76.790             |1460.156           |68.48 K/s          |
|q19                |100,000,000        |19.43              |89.342             |1736.054           |57.6 K/s           |
|q20                |100,000,000        |20.66              |210.903            |4357.486           |22.95 K/s          |
|q21                |100,000,000        |23.45              |34.331             |805.157            |124.2 K/s          |
|q22                |100,000,000        |�                  |25.187             |NaN                |0/s                |
|Total              |2,200,000,000      |.xxxxxx            |1870.692           |                   |                   |

### 
+-------------------+-------------------+-------------------+-------------------+-------------------+-------------------+
| Nexmark Query     | Events Num        | Cores             | Time(s)           | Cores * Time(s)   | Throughput/Cores  |
+-------------------+-------------------+-------------------+-------------------+-------------------+-------------------+
|q0                 |100,000,000        |23.74              |12.919             |306.760            |325.99 K/s         |
|q1                 |100,000,000        |23.6               |13.372             |315.546            |316.91 K/s         |
|q2                 |100,000,000        |23.75              |11.861             |281.736            |354.94 K/s         |
|q3                 |100,000,000        |23.57              |16.309             |384.337            |260.19 K/s         |
|q4                 |100,000,000        |19.77              |133.238            |2634.119           |37.96 K/s          |
|q5                 |100,000,000        |13.3               |99.448             |1322.366           |75.62 K/s          |
|q7                 |100,000,000        |19.75              |190.953            |3772.256           |26.51 K/s          |
|q8                 |100,000,000        |�                  |19.662             |NaN                |0/s                |
|q9                 |100,000,000        |14.74              |328.936            |4849.509           |20.62 K/s          |
|q10                |100,000,000        |13.46              |82.066             |1104.594           |90.53 K/s          |
|q11                |100,000,000        |22.4               |119.104            |2668.182           |37.48 K/s          |
|q12                |100,000,000        |20.43              |31.338             |640.367            |156.16 K/s         |
|q13                |100,000,000        |21.17              |19.233             |407.250            |245.55 K/s         |
|q14                |100,000,000        |23.74              |13.959             |331.330            |301.81 K/s         |
|q15                |100,000,000        |23.54              |53.502             |1259.427           |79.4 K/s           |
|q16                |100,000,000        |20.02              |295.443            |5914.293           |16.91 K/s          |
|q17                |100,000,000        |17.78              |29.993             |533.330            |187.5 K/s          |
|q18                |100,000,000        |19.74              |77.880             |1537.699           |65.03 K/s          |
|q19                |100,000,000        |14.41              |105.853            |1525.852           |65.54 K/s          |
|q20                |100,000,000        |19.61              |106.631            |2091.369           |47.81 K/s          |
|q21                |100,000,000        |22.28              |30.880             |687.990            |145.35 K/s         |
|q22                |100,000,000        |21.95              |20.029             |439.679            |227.44 K/s         |
|Total              |2,200,000,000      |.xxxxxx            |1812.609           |                   |                   |


########################################################################################
# Result Summary: ecs.r9ae.2xlarge（SMT OFF）
# -------------------------------- Nexmark Results --------------------------------
+-------------------+-------------------+-------------------+-------------------+-------------------+-------------------+
| Nexmark Query     | Events Num        | Cores             | Time(s)           | Cores * Time(s)   | Throughput/Cores  |
+-------------------+-------------------+-------------------+-------------------+-------------------+-------------------+
|q0                 |100,000,000        |�                  |14.531             |NaN                |0/s                |
|q1                 |100,000,000        |�                  |14.637             |NaN                |0/s                |
|q2                 |100,000,000        |�                  |14.625             |NaN                |0/s                |
|q3                 |100,000,000        |20.8               |11.528             |239.829            |416.96 K/s         |
|q4                 |100,000,000        |18.79              |98.776             |1855.556           |53.89 K/s          |
|q5                 |100,000,000        |11.99              |87.103             |1044.653           |95.72 K/s          |
|q7                 |100,000,000        |18.55              |166.932            |3096.267           |32.3 K/s           |
|q8                 |100,000,000        |�                  |19.680             |NaN                |0/s                |
|q9                 |100,000,000        |18.7               |108.245            |2023.651           |49.41 K/s          |
|q10                |100,000,000        |11.02              |81.116             |893.663            |111.9 K/s          |
|q11                |100,000,000        |22.06              |81.702             |1801.953           |55.49 K/s          |
|q12                |100,000,000        |�                  |20.424             |NaN                |0/s                |
|q13                |100,000,000        |23.29              |11.834             |275.665            |362.76 K/s         |
|q14                |100,000,000        |19.61              |12.438             |243.934            |409.95 K/s         |
|q15                |100,000,000        |22.43              |37.959             |851.311            |117.47 K/s         |
|q16                |100,000,000        |18.42              |248.487            |4577.647           |21.84 K/s          |
|q17                |100,000,000        |�                  |21.779             |NaN                |0/s                |
|q18                |100,000,000        |17.21              |67.244             |1157.190           |86.42 K/s          |
|q19                |100,000,000        |16.99              |77.032             |1308.822           |76.4 K/s           |
|q20                |100,000,000        |15.88              |183.946            |2921.307           |34.23 K/s          |
|q21                |100,000,000        |�                  |22.808             |NaN                |0/s                |
|q22                |100,000,000        |19.08              |15.095             |288.084            |347.12 K/s         |
|Total              |2,200,000,000      |.xxxxxx            |1417.921           |                   |                   |
