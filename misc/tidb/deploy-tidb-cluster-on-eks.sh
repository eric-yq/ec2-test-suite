# 创建集群
eksctl create cluster -f tidb-cluster.yaml 

# 创建 IAM
eksctl utils associate-iam-oidc-provider --region=us-east-2 --cluster=tidb-cluster --approve
eksctl create iamserviceaccount \
        --name ebs-csi-controller-sa \
        --namespace kube-system \
        --cluster tidb-cluster \
        --role-name AmazonEKS_EBS_CSI_DriverRole \
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

# 部署 TiDB Operator
## 安装 TiDB Operator CRDs
kubectl create -f https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.3/manifests/crd.yaml
## 添加 PingCAP 仓库。
helm repo add pingcap https://charts.pingcap.org/
## 为 TiDB Operator 创建一个命名空间。
kubectl create namespace tidb-admin
## 安装 TiDB Operator
helm install --namespace tidb-admin tidb-operator pingcap/tidb-operator --version v1.6.3
## 查看 TiDB Operator Pod 状态
kubectl get pods --namespace tidb-admin -l app.kubernetes.io/instance=tidb-operator

# 部署 TiDB 集群
## 创建 TiDB 集群命名空间
kubectl create namespace tidb-cluster
## 下载 TidbCluster 和 TidbMonitor CR 的配置文件。
mkdir -p tidb-cluster-software-config
cd tidb-cluster-software-config
curl -O https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.3/examples/aws/tidb-cluster.yaml
curl -O https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.3/examples/aws/tidb-monitor.yaml
curl -O https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.3/examples/aws/tidb-dashboard.yaml
###### 修改参数，参考 tidb-cluster-software-config/tidb-cluster.yaml ######
# ......
## 执行部署 TiDB 集群
kubectl apply -f tidb-cluster.yaml -n tidb-cluster
## 查看 TiDB 集群 Pod 状态
kubectl get pvc  -n tidb-cluster -o wide
kubectl get pods -n tidb-cluster -o wide


## 附加：删除 TiDB 集群
# kubectl delete tc basic -n tidb-cluster


#################################################################################################################
# TiDB TPC-H 测试脚本 , 在一台 tidb-client 实例上执行.
# 该实例和 tidb-node 在同一个 subnet 和 安全组，同时加入 default 安全组
# vpc-04d912211c6bd7a62
# subnet-0cdd03810ae987830
# sg-0b34e9daa975cd219
# sg-0cd1e981530784bb6
#################################################################################################################
# 安装基础软件包
yum update -yq
yum install -yq python3-pip htop
pip3 install dool
rpm -Uvh https://repo.mysql.com/mysql80-community-release-el9.rpm
yum install -yq mysql

# 测试 mysql 客户端远程访问
# kubectl get svc basic-tidb -n tidb-cluster -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
tidb_host="a1d9f7f96cd3b4f919c8af2fbec68888-5ed09ee5e8020c5c.elb.us-east-2.amazonaws.com"
mysql --comments -h ${tidb_host} -P 4000 -u root -e "show databases;"

# 安装 TiUP
cd /root/
curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh
source /root/.bash_profile
tiup install playground
tiup install bench

# 准备数据
screen -R ttt -L
sf=300
tidb_host="a1d9f7f96cd3b4f919c8af2fbec68888-5ed09ee5e8020c5c.elb.us-east-2.amazonaws.com"
tidb_port=4000
tiup bench tpch prepare \
  --sf $sf --dropdata --threads 16 \
  --host ${tidb_host} --port ${tidb_port} --db tpch${sf} \
  --analyze \
  --tiflash-replica 3
  
#   --tidb_build_stats_concurrency 8 \
#   --tidb_distsql_scan_concurrency 30 \
#   --tidb_index_serial_scan_concurrency 8 \

#################################################################################################################
## 常用操作 eks-and-tidb-commands.sh
#################################################################################################################


#################################################################################################################
# 运行 TPC-H 查询
# 执行测试:q4,q17 这两条查询在 SF500 有点问题，先不执行
sf=300
tidb_host="a1d9f7f96cd3b4f919c8af2fbec68888-5ed09ee5e8020c5c.elb.us-east-2.amazonaws.com"
tidb_port=4000
tiup bench tpch run \
  --host ${tidb_host} --port ${tidb_port} --db tpch${sf} \
  --sf ${sf} \
  --conn-params="tidb_isolation_read_engines = 'tiflash'" \
  --conn-params="tidb_allow_mpp = 1" \
  --conn-params="tidb_enforce_mpp = 0" \
  --conn-params="tidb_mem_quota_query = 34359738368" \
  --conn-params="tidb_broadcast_join_threshold_count=10000000" \
  --conn-params="tidb_broadcast_join_threshold_size=104857600" \
  --queries "q1,q2,q3,q4,q5,q6,q7,q8,q9,q10,q11,q12,q13,q14,q15,q16,q17,q18,q19,q20,q21,q22"


####
LIST="q1 q2 q3 q4 q5 q6 q7 q8 q9 q10 q11 q12 q13 q14 q15 q16 q17 q18 q19 q20 q21 q22"
for i in $LIST; do
  tiup bench tpch run \
    --host ${tidb_host} --port ${tidb_port} --db tpch${sf} \
    --conn-params="tidb_isolation_read_engines = 'tiflash'" \
    --conn-params="tidb_allow_mpp = 1" \
    --conn-params="tidb_enforce_mpp = 0" \
    --conn-params="tidb_mem_quota_query = 34359738368" \
    --conn-params="tidb_broadcast_join_threshold_count=10000000" \
    --conn-params="tidb_broadcast_join_threshold_size=104857600" \
    --queries "$i" \
    --count 1
  
  sleep 10
done
