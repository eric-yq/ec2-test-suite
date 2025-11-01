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
kubectl get pods -n tidb-cluster -o wide
kubectl get pvc  -n tidb-cluster -o wide

## 附加：删除 TiDB 集群
kubectl delete tc basic -n tidb-cluster

# 测试 mysql 客户端远程访问
EXTERNAL_IP=$(kubectl get svc basic-tidb -n tidb-cluster -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo $EXTERNAL_IP
mysql --comments -h a69ffeedf46f247f8bb0203acd486c43-78d600dac3ead463.elb.us-east-2.amazonaws.com -P 4000 -u root

#################################################################################################################
# TiDB TPC-H 测试脚本 , 在一台 tidb-client 节点上执行
#################################################################################################################
# 准备数据
screen -R ttt -L
SF=300
tidb_host="a69ffeedf46f247f8bb0203acd486c43-78d600dac3ead463.elb.us-east-2.amazonaws.com"
tidb_port=4000
tiup bench tpch prepare \
  --sf $SF --dropdata --threads 64 \
  --host ${tidb_host} --port ${tidb_port} --db tpch$SF \
  --analyze \
  --tiflash-replica 3
  
#   --tidb_build_stats_concurrency 8 \
#   --tidb_distsql_scan_concurrency 30 \
#   --tidb_index_serial_scan_concurrency 8 \

# 查询数据表容量
mysql --comments -h a69ffeedf46f247f8bb0203acd486c43-78d600dac3ead463.elb.us-east-2.amazonaws.com -P 4000 -u root
## 执行下面SQL
## -- 查询各个表占用的磁盘容量
SELECT 
    table_name,
    CONCAT(ROUND(data_length/1024/1024, 2), ' MB') as data_size
FROM 
    information_schema.tables 
WHERE 
    table_schema = 'test' 
ORDER BY 
    data_length DESC;
# +------------+--------------+
# | table_name | data_size    |
# +------------+--------------+
# | lineitem   | 230042.63 MB |
# | orders     | 49846.07 MB  |
# | partsupp   | 35796.75 MB  |
# | customer   | 8583.21 MB   |
# | part       | 7176.87 MB   |
# | supplier   | 633.61 MB    |
# | nation     | 0.00 MB      |
# | region     | 0.00 MB      |
# +------------+--------------+
# 8 rows in set (0.00 sec)

## -- 查询各个表的记录数
SELECT 
    table_name, 
    table_rows
FROM 
    information_schema.tables 
WHERE 
    table_schema = 'test' 
ORDER BY 
    table_name;
# +------------+------------+
# | table_name | table_rows |
# +------------+------------+
# | customer   |   53541403 |
# | lineitem   | 1803017836 |
# | nation     |         25 |
# | orders     |  450000000 |
# | part       |   60000000 |
# | partsupp   |  240000000 |
# | region     |          5 |
# | supplier   |    4489600 |
# +------------+------------+
# 8 rows in set (0.00 sec)

# -- 查询所有存储节点信息
SELECT 
    store_id,
    address,
    store_state,
    capacity,
    available,
    capacity - available AS used,
    (capacity - available) / capacity AS usage_ratio,
    version
FROM 
    information_schema.tikv_store_status
ORDER BY address;


#################################################################################################################
# 运行 TPC-H 查询
# 执行测试:q4,q17 这两条查询在 SF500 有点问题，先不执行
SF=300
tidb_host="a69ffeedf46f247f8bb0203acd486c43-78d600dac3ead463.elb.us-east-2.amazonaws.com"
tidb_port=4000
tiup bench tpch run \
  --host ${tidb_host} --port ${tidb_port} \
  --sf ${SF} \
  --conn-params="tidb_isolation_read_engines = 'tiflash'" \
  --conn-params="tidb_allow_mpp = 1" \
  --conn-params="tidb_enforce_mpp = 0" \
  --conn-params="tidb_mem_quota_query = 34359738368" \
  --conn-params="tidb_broadcast_join_threshold_count=10000000" \
  --conn-params="tidb_broadcast_join_threshold_size=104857600" \
  --queries "q1,q2,q3,q5,q6,q7,q8,q9,q10,q11,q12,q13,q14,q15,q16,q18,q19,q20,q21,q22"





   





#################################################################################################################
# 为 TPC-H 表创建 TiFlash 副本
## TPC-H 查询是分析型工作负载，使用 TiFlash 能显著提升性能：
mysql --comments -h a69ffeedf46f247f8bb0203acd486c43-78d600dac3ead463.elb.us-east-2.amazonaws.com -P 4000 -u root
## 执行下面SQL：（顺序按上面查询结果调整为从小到大）
ALTER TABLE region SET TIFLASH REPLICA 1;
ALTER TABLE nation SET TIFLASH REPLICA 1;
ALTER TABLE supplier SET TIFLASH REPLICA 1;
ALTER TABLE part SET TIFLASH REPLICA 1;
ALTER TABLE customer SET TIFLASH REPLICA 1;
ALTER TABLE partsupp SET TIFLASH REPLICA 1;
ALTER TABLE orders SET TIFLASH REPLICA 1;
ALTER TABLE lineitem SET TIFLASH REPLICA 1;
## 等待副本创建完成，可以通过下面 SQL 查看进度：1代表完成
SELECT * FROM information_schema.tiflash_replica WHERE TABLE_SCHEMA = 'test' ORDER BY TABLE_NAME;

## 不进入mysql 客户端，直接执行SQL
mysql --comments -h a69ffeedf46f247f8bb0203acd486c43-78d600dac3ead463.elb.us-east-2.amazonaws.com -P 4000 -u root \
  -e "SELECT * FROM information_schema.tiflash_replica WHERE TABLE_SCHEMA = 'test' ORDER BY TABLE_NAME;"

