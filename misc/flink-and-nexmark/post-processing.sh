#!/bin/bash

# for Amazon Linux 2023，使用 ec2-user 用户登录执行

su - ec2-user

# 在使用 flink-nexmark AMI 启动 3 台实例后，
# 分别通过 SSH 登录到 Master 和 2 个 Worker 节点，执行下面命令完成 Flink 和 Nexmark 的安装与基准测试。

## 将 下列 3 个 IPADDR_xxx 变量设置为 3 台 EC2 实例的 VPC IP 地址，并保存在 /etc/hosts 文件中
IPADDR_MASTER="172.31.88.17"
IPADDR_WORKER1="172.31.81.218"
IPADDR_WORKER2="172.31.94.90"
cat << EOF | sudo tee -a /etc/hosts
$IPADDR_MASTER  master
$IPADDR_WORKER1 worker1
$IPADDR_WORKER2 worker2
EOF

## 生成密钥, 将 master 和 worker1,2 节点的 
## id_rsa.pub 添加到所有节点的 authorized_keys 文件
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub 
chmod 0600 ~/.ssh/authorized_keys
vim ~/.ssh/authorized_keys
### 保存退出

#####################################################################
## 在 Master 节点继续执行下面操作
#####################################################################
# Flink-nexmark AMI 是按照 48G 进行的配置；如果是内存不是 48G 的话，根据需要修改。
# 48G 是 Flink 的 TaskManager 的 JVM 堆内存设置，如果内存不是 48G 的话，根据需要修改。
cd /home/ec2-user/flink-benchmark
CPU_CORES=$(nproc)
MEM_TOTAL_GB=$(free -g |grep Mem | awk -F " " '{print $2}')
let XXX=${MEM_TOTAL_GB}*75/100
sed -i "s/48G/${XXX}G/g" nexmark-flink/conf/config.yaml
# 或者：修改slot
sed -i "s/taskmanager.numberOfTaskSlots: 8/taskmanager.numberOfTaskSlots: ${CPU_CORES}/g" nexmark-flink/conf/config.yaml


# 启动 Flink 集群和 Benchmark
bash ~/flink-benchmark/flink/bin/start-cluster.sh
bash ~/flink-benchmark/nexmark-flink/bin/setup_cluster.sh

# 开始执行 Benchmark
#####################################################################
## 在 Master 节点继续执行下面操作
#####################################################################
# 试跑一个查询:
bash ~/flink-benchmark/nexmark-flink/bin/run_query.sh q7

# screen -R ttt -L
# 执行任务
bash ~/flink-benchmark/nexmark-flink/bin/run_query.sh all
sleep 10

# 设置一个结果文件
cd ~
instance_type=$(ec2-metadata --quiet --instance-type)
timestamp=$(date +%Y%m%d%H%M%S)
RESULT_FILE="flink-nexmark-result-$instance_type-$timestamp.txt"
aws s3 cp screenlog.0 s3://ec2-core-benchmark-ericyq/result_flink/$RESULT_FILE


## 方法 2: 执行单独的 SQL， q6 有问题无法执行
for i in `seq 0 22` 
do
    bash ~/flink-benchmark/nexmark-flink/bin/run_query.sh q$i
    sleep 10
done

#####################################################################
## 查看日志
grep "Start to run query"  screenlog.0
grep "Stop job query"      screenlog.0
grep "Exception in thread" screenlog.0
grep "Summary Average:"    screenlog.0

grep -E "query|Exception|Summary" screenlog.0 
 
## 停止集群 和 benchmark
bash ~/flink-benchmark/nexmark-flink/bin/shutdown_cluster.sh
bash ~/flink-benchmark/flink/bin/stop-cluster.sh
