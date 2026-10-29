# 本次要测试的实例家族类型 
INSTANCE_FAMILY="r9g"
GENERATION=${INSTANCE_FAMILY: -2}
echo $GENERATION

# 准备配置文件
cd /root/ec2-test-suite/misc/tidb/test-suite
cp -r r8g ${INSTANCE_FAMILY}
cd /root/ec2-test-suite/misc/tidb/test-suite/${INSTANCE_FAMILY}
sed "s/8g/${GENERATION}/g" eks/tidb-cluster.yaml

###################################################################################################
# 创建集群
cd eks
eksctl create cluster -f tidb-cluster.yaml 

# 创建 IAM
eksctl utils associate-iam-oidc-provider --region=us-east-2 --cluster=tidb-cluster-${INSTANCE_FAMILY} --approve
eksctl create iamserviceaccount \
        --name ebs-csi-controller-sa \
        --namespace kube-system \
        --cluster tidb-cluster-${INSTANCE_FAMILY} \
        --role-name AmazonEKS_EBS_CSI_DriverRole-${INSTANCE_FAMILY} \
        --role-only \
        --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
        --approve

# 设置 ebs-csi-node toleration
kubectl patch -n kube-system ds ebs-csi-node -p '{"spec":{"template":{"spec":{"tolerations":[{"operator":"Exists"}]}}}}'

# 应用这 3 个 StorageClass
kubectl apply -f tikv-gp3-storageclass.yaml
kubectl apply -f tiflash-gp3-storageclass.yaml
kubectl apply -f default-gp3-storageclass.yaml
kubectl get storageclass gp3-tikv gp3-tiflash gp3-default
kubectl get sc

###################################################################################################
# 部署 TiDB Operator
## 安装 TiDB Operator CRDs
kubectl create -f https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.3/manifests/crd.yaml
## 添加 PingCAP 仓库。
helm repo add pingcap https://charts.pingcap.com/
## 为 TiDB Operator 创建一个命名空间。
kubectl create namespace tidb-admin
## 安装 TiDB Operator
helm install --namespace tidb-admin tidb-operator pingcap/tidb-operator --version v1.6.3
## 查看 TiDB Operator Pod 状态
kubectl get pods --namespace tidb-admin -l app.kubernetes.io/instance=tidb-operator

###################################################################################################
# 部署 TiDB 集群
## 创建 TiDB 集群命名空间
kubectl create namespace tidb-cluster-${INSTANCE_FAMILY}
## 下载 TidbCluster 和 TidbMonitor CR 的配置文件。
cd ../tidb-deployment
# curl -O https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.3/examples/aws/tidb-cluster.yaml
# curl -O https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.3/examples/aws/tidb-monitor.yaml
# curl -O https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.3/examples/aws/tidb-dashboard.yaml
###### 修改参数，参考 tidb-deployment/tidb-cluster.yaml ######
# ......
## 执行部署 TiDB 集群
kubectl apply -f tidb-cluster.yaml -n tidb-cluster-${INSTANCE_FAMILY}
## 查看 TiDB 集群 Pod 状态
kubectl get pvc  -n tidb-cluster-${INSTANCE_FAMILY} -o wide
kubectl get pods -n tidb-cluster-${INSTANCE_FAMILY} -o wide

# 查询 TiDB 访问地址
kubectl get svc basic-tidb -n tidb-cluster-${INSTANCE_FAMILY} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
tidb_host="acbb9153ddd0b4915b8ec30ee2c46f47-0e3f4c123ad209df.elb.us-east-2.amazonaws.com"


## 附加：删除 TiDB 集群
# kubectl delete tc basic -n tidb-cluster-${INSTANCE_FAMILY}


#################################################################################################################
# TiDB TPC-H 测试脚本 , 在一台 tidb-client 实例上执行.
# 该实例和 tidb-node 在同一个 subnet 和 安全组，同时加入 default 安全组
# vpc-00dff4c509ba673b8
# subnet-0691c2ea78520c3f7
# sg-0cb2fd382e1534e25
# sg-0a5a40cef0d729653
# 这个实例在启动之后，没有公网 IP 地址，通过控制台连接。
#################################################################################################################
# 安装基础软件包
yum update -yq
yum install -yq python3-pip htop
pip3 install dool
rpm -Uvh https://repo.mysql.com/mysql80-community-release-el9.rpm
yum install -yq mysql

# 测试 mysql 客户端远程访问
cat >> ~/.bash_profile << EOF
alias ccc="clear"
alias ddd="dool 1 10"
alias sttt="screen -r ttt"
alias tailf="tail ~/screenlog.0"
export tidb_host="acbb9153ddd0b4915b8ec30ee2c46f47-0e3f4c123ad209df.elb.us-east-2.amazonaws.com"
export sf=300
export wares=1000
EOF
source ~/.bash_profile
mysql -h ${tidb_host} -P 4000 -u root -e "show databases;"

# 安装 TiUP
cd /root/
curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh
source /root/.bash_profile
tiup install playground
tiup install bench

#################################################################################################################
# TPCH 准备数据：下面内容可以保存为 prepare-tpch300.sh , 然后执行。
# screen -R ttt -L
#!/bin/bash
sf=300
tidb_host="acbb9153ddd0b4915b8ec30ee2c46f47-0e3f4c123ad209df.elb.us-east-2.amazonaws.com"
tiup bench tpch prepare \
  --sf $sf --dropdata --threads 16 \
  --host ${tidb_host} --port 4000 --db tpch${sf} \
  --analyze \
  --tidb_build_stats_concurrency 4 \
  --tidb_distsql_scan_concurrency 15 \
  --tidb_index_serial_scan_concurrency 4 \
  --tiflash-replica 3

echo "[Info] Complete to prepare tpch${sf}." && sleep 60
echo "[Info] Start to analyze tables..."
# 分析表统计信息的单独 SQL
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpch${sf}.customer;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpch${sf}.lineitem;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpch${sf}.nation;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpch${sf}.orders;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpch${sf}.part;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpch${sf}.partsupp;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpch${sf}.region;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpch${sf}.supplier;"

echo "[Info] Complete to prepare and analyze tpch${sf}, you can start to run benchmark."
#################################################################################################################
bash prepare-tpch300.sh

#################################################################################################################
## 常用操作 eks-and-tidb-commands.sh
#################################################################################################################

#################################################################################################################
# 运行 TPC-H 查询
# 执行测试: q4 查询有点问题，先不执行
# screen -R ttt -L
sf=300
tidb_host="acbb9153ddd0b4915b8ec30ee2c46f47-0e3f4c123ad209df.elb.us-east-2.amazonaws.com"
LIST="q1 q2 q3 q5 q6 q7 q8 q9 q10 q11 q12 q13 q14 q15 q16 q17 q18 q19 q20 q21 q22"
for i in $LIST; do
  tiup bench tpch run \
    --host ${tidb_host} --port 4000 --db tpch${sf} \
    --conn-params="tidb_isolation_read_engines = 'tiflash'" \
    --conn-params="tidb_allow_mpp = 1" \
    --conn-params="tidb_enforce_mpp = 1" \
    --conn-params="tidb_opt_tiflash_concurrency_factor = 4" \
    --conn-params="tidb_opt_mpp_outer_join_fixed_build_side = 0" \
    --conn-params="tiflash_mpp_task_max_concurrency = 8" \
    --conn-params="tidb_mem_quota_query = 137438953472" \
    --conn-params="tidb_broadcast_join_threshold_count=10000000" \
    --conn-params="tidb_broadcast_join_threshold_size=104857600" \
    --count 3 \
    --queries "$i" >> result_tpch${sf}.txt 2>&1
    
  sleep 10  
done
echo "[Info] Complete to run tpch${sf} tests."
grep Summary result_tpch${sf}.txt > result_summary_tpch${sf}_${INSTANCE_FAMILY}.txt

#################################################################################################################
# TPCC 准备数据：下面内容可以保存为 prepare-tpcc1000.sh , 然后执行。
# screen -R ttt -L
#!/bin/bash
source .bash_profile
wares=1000
tidb_host="acbb9153ddd0b4915b8ec30ee2c46f47-0e3f4c123ad209df.elb.us-east-2.amazonaws.com"
tiup bench tpcc prepare \
  --host ${tidb_host} --port 4000 \
  --db tpcc${wares} --warehouses ${wares} --dropdata \
  --threads 16 --parts 16 --isolation 2 \
  --conn-params "tidb_batch_insert=1" \
  --conn-params "tidb_batch_delete=1" \
  --conn-params "tidb_enable_streaming=1" \
  --conn-params "tidb_disable_txn_auto_retry=0" \
  --conn-params "tidb_constraint_check_in_place=0" \
  --conn-params "tidb_txn_mode=optimistic" \
  --conn-params "tidb_enable_batch_dml=1" \
  --conn-params "tidb_dml_batch_size=2000" \
  --conn-params "tidb_distsql_scan_concurrency=16" \
  --conn-params "tidb_index_serial_scan_concurrency=8" \
  --conn-params "tidb_projection_concurrency=8" \
  --conn-params "tidb_hashagg_partial_concurrency=8" \
  --conn-params "tidb_hashagg_final_concurrency=8" \
  --conn-params "tidb_init_chunk_size=1024" \
  --conn-params "tidb_max_chunk_size=4096" \
  --conn-params "tidb_mem_quota_query=8 << 30" 

# 收集统计信息
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpcc${wares}.customer;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpcc${wares}.district;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpcc${wares}.history;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpcc${wares}.item;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpcc${wares}.new_order;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpcc${wares}.order_line;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpcc${wares}.orders;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpcc${wares}.stock;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpcc${wares}.warehouse;"

# 查看各个表的记录数
wares=1000
mysql -h ${tidb_host} -P 4000 -u root -e "SELECT COUNT(*) FROM tpcc${wares}.customer;"
mysql -h ${tidb_host} -P 4000 -u root -e "SELECT COUNT(*) FROM tpcc${wares}.district;"
mysql -h ${tidb_host} -P 4000 -u root -e "SELECT COUNT(*) FROM tpcc${wares}.history;"
mysql -h ${tidb_host} -P 4000 -u root -e "SELECT COUNT(*) FROM tpcc${wares}.item;"
mysql -h ${tidb_host} -P 4000 -u root -e "SELECT COUNT(*) FROM tpcc${wares}.new_order;"
mysql -h ${tidb_host} -P 4000 -u root -e "SELECT COUNT(*) FROM tpcc${wares}.order_line;"
mysql -h ${tidb_host} -P 4000 -u root -e "SELECT COUNT(*) FROM tpcc${wares}.orders;"
mysql -h ${tidb_host} -P 4000 -u root -e "SELECT COUNT(*) FROM tpcc${wares}.stock;"
mysql -h ${tidb_host} -P 4000 -u root -e "SELECT COUNT(*) FROM tpcc${wares}.warehouse;"

echo "[Info] Complete to prepare and analyze tpcc${wares}, you can start to run benchmark."
sleep 60

###################################################################################################
# 执行 TPCC 测试
wares=1000
LIST="10 30 50 70 100"
for i in $LIST; do
  echo "[Info] Start to run tpcc test with ${i} threads."
  tiup bench tpcc run \
    --host ${tidb_host} --port 4000 \
    --db tpcc${wares} --warehouses ${wares} \
    --threads ${i} --time 1h \
    > result_summary_tpcc${wares}_threads_${i}.txt 2>&1

    sleep 60
done

tail -n 1 result_summary_tpcc*.txt > result_summary_tpcc${wares}_${INSTANCE_FAMILY}.txt
#################################################################################################################