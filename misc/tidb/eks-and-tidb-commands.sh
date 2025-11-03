#################################################################################################################
## 查询 EKS 信息

# 查看命名空间 namespace
kubectl get ns

# 查看当前使用的上下文
kubectl config current-context

# 查看所有可用的上下文
kubectl config get-contexts

# 切换到 tidb-cluster 集群
kubectl config use-context admin@tidb-cluster.us-east-2.eksctl.io 
kubectl config use-context admin@arm64-tidb-cluster.us-east-2.eksctl.io 

#################################################################################################################
## 查询 TiDB 主机信息，用于 mysql 客户端 和 tiup bench 进行连接：
tidb_host=$(kubectl get svc basic-tidb \
  -n tidb-cluster-arm64 \  ## 当前 context 包含的命名空间
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

#################################################################################################################
# 在 TiDB Client 实例上设置环境变量
## x86
cat >> ~/.bash_profile << EOF
alias ccc="clear"
alias ddd="dool 1 10"
alias sttt="screen -r ttt"
alias tailf="tail ~/screenlog.0"
tidb_host="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.elb.us-east-2.amazonaws.com"
sf=300
wares=1000
EOF
source ~/.bash_profile

# r8g
tidb_host="a8a4039336bd04644a7bfe24b4b39286-74e2214757238f41.elb.us-east-2.amazonaws.com"

# r8i
tidb_host="ac81a8793a79f44d9a560563d438b9c3-e050f6905097f21d.elb.us-east-2.amazonaws.com"

# r6i
tidb_host="a1d9f7f96cd3b4f919c8af2fbec68888-5ed09ee5e8020c5c.elb.us-east-2.amazonaws.com"

#################################################################################################################
# 查询 TPC-H 数据库和表的信息
mysql -h ${tidb_host} -P 4000 -u root
mysql -h ${tidb_host} -P 4000 -u root -e "show databases;"

# -- 查询tiflash 同步状态
mysql -h ${tidb_host} -P 4000 -u root -e \
  "SELECT * FROM information_schema.tiflash_replica WHERE TABLE_SCHEMA = 'tpch$sf' ORDER BY TABLE_NAME;"

# -- 查询所有存储节点信息
mysql -h ${tidb_host} -P 4000 -u root -e \
  "SELECT store_id, address, store_state, capacity, available, capacity - available AS used, (capacity - available) / capacity AS usage_ratio, version FROM information_schema.tikv_store_status ORDER BY address;"
 
## -- 查询各个表占用的磁盘容量
mysql -h ${tidb_host} -P 4000 -u root -e \
  "SELECT table_name, CONCAT(ROUND(data_length/1024/1024, 2), ' MB') as data_size FROM information_schema.tables WHERE table_schema = 'tpch$sf' ORDER BY table_name;"

## -- 查询各个表的记录数
mysql -h ${tidb_host} -P 4000 -u root -e \
  "SELECT table_name, table_rows FROM information_schema.tables  WHERE table_schema = 'tpch$sf' ORDER BY table_name;"


#################################################################################################################
# 查询 TPC-C 数据库和表的信息
# -- 查询所有存储节点信息
mysql -h ${tidb_host} -P 4000 -u root -e \
  "SELECT store_id, address, store_state, capacity, available, capacity - available AS used, (capacity - available) / capacity AS usage_ratio, version FROM information_schema.tikv_store_status ORDER BY address;"
 
## -- 查询各个表占用的磁盘容量
mysql -h ${tidb_host} -P 4000 -u root -e \
  "SELECT table_name, CONCAT(ROUND(data_length/1024/1024, 2), ' MB') as data_size FROM information_schema.tables WHERE table_schema = 'tpcc$wares' ORDER BY table_name;"

## -- 查询各个表的记录数
mysql -h ${tidb_host} -P 4000 -u root -e \
  "SELECT table_name, table_rows FROM information_schema.tables  WHERE table_schema = 'tpcc$wares' ORDER BY table_name;"
