

#################################################################################################################
## 查询 EKS 信息

# 查看当前使用的上下文
kubectl config current-context

# 查看所有可用的上下文
kubectl config get-contexts

# 切换到 tidb-cluster 集群
kubectl config use-context admin@tidb-cluster.us-east-2.eksctl.io 



#################################################################################################################
## 查询 TiDB 数据库和表的信息
mysql --comments  -h ${tidb_host} -P ${tidb_port} -u root

## x86
tidb_host="a69ffeedf46f247f8bb0203acd486c43-78d600dac3ead463.elb.us-east-2.amazonaws.com"
tidb_port=4000

## arm64
tidb_host="a363275b91da64ac9b1a4b6e39510533-5be95794feb4c9c8.elb.us-east-2.amazonaws.com"
tidb_port=4000

# -- 查询所有存储节点信息
mysql --comments  -h ${tidb_host} -P ${tidb_port} -u root -e "SELECT store_id, address, store_state, capacity, available, capacity - available AS used, (capacity - available) / capacity AS usage_ratio, version FROM information_schema.tikv_store_status ORDER BY address;"
 
## -- 查询各个表占用的磁盘容量
mysql --comments  -h ${tidb_host} -P ${tidb_port} -u root -e "SELECT table_name, CONCAT(ROUND(data_length/1024/1024, 2), ' MB') as data_size FROM information_schema.tables WHERE table_schema = 'test' ORDER BY data_length DESC;"

## -- 查询各个表的记录数
mysql --comments  -h ${tidb_host} -P ${tidb_port} -u root -e "SELECT table_name, table_rows FROM information_schema.tables  WHERE table_schema = 'test' ORDER BY table_name;"

mysql --comments  -h ${tidb_host} -P ${tidb_port} -u root -e "SELECT * FROM information_schema.tiflash_replica WHERE TABLE_SCHEMA = 'test' ORDER BY TABLE_NAME;"

#################################################################################################################