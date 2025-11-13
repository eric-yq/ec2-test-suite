#!/bin/bash

# for Amazon Linux 2023，使用 ec2-user 用户登录执行

# 在使用 flink-nexmark AMI 启动 3 台实例后，
# 分别通过 SSH 登录到 Master 和 2 个 Worker 节点，执行下面命令完成 Flink 和 Nexmark 的安装与基准测试。

## 生成密钥
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
chmod 0600 ~/.ssh/authorized_keys
## 将 master 和 worker1,2 节点的【cat ~/.ssh/id_rsa.pub】 的输出结果添加到所有节点的 authorized_keys 文件
cat ~/.ssh/id_rsa.pub 
vim ~/.ssh/authorized_keys
### 保存退出

## 将 下列 3 个 IPADDR_xxx 变量设置为 3 台 EC2 实例的 VPC IP 地址，并保存在 /etc/hosts 文件中
IPADDR_MASTER="172.31.23.209"
IPADDR_WORKER1="172.31.18.121"
IPADDR_WORKER2="172.31.30.234"
cat << EOF | sudo tee -a /etc/hosts
$IPADDR_MASTER  master
$IPADDR_WORKER1 worker1
$IPADDR_WORKER2 worker2
EOF

#####################################################################
## 在 Master 节点继续执行下面操作
#####################################################################
bash ~/flink-benchmark/flink/bin/start-cluster.sh
bash ~/flink-benchmark/nexmark-flink/bin/setup_cluster.sh

# 开始执行 Benchmark
#####################################################################
## 在 Master 节点继续执行下面操作
#####################################################################
# 试跑一个查询:
bash ~/flink-benchmark/nexmark-flink/bin/run_query.sh q10

# 这是一个结果文件
instance_type=$(ec2-metadata --quiet --instance-type)
timestamp=$(date +%Y%m%d%H%M%S)
RESULT_FILE="/flink-nexmark-result-$instance_type-$timestamp.txt"

## 方法 1: 运行 benchmark 的所有 SQL
cd ~
screen -R ttt -L
bash ~/flink-benchmark/nexmark-flink/bin/run_query.sh all >> $RESULT_FILE

## 方法 2: 执行单独的 SQL， q6 有问题无法执行
for i in `seq 0 22` 
do
    bash ~/flink-benchmark/nexmark-flink/bin/run_query.sh q$i >> $RESULT_FILE
    sleep 10
done

## 结果上传到 S3
cd ~
aws s3 cp $RESULT_FILE s3://ec2-core-benchmark-ericyq/result_flink/


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
