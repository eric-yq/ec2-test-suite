# 设置 MongoDB 的地址
SUT_IP_ADDR=172.31.2.175


HOSTS="${SUT_IP_ADDR}:27017"   
MONGO_URL=mongodb://root:gv2mongo@${HOSTS}/

# 加载数据 
/root/ycsb-0.17.0/bin/ycsb load mongodb \
  -P /root/ec2-test-suite/benchmark/workload_mongo \
  -p mongodb.url=${MONGO_URL} -threads $(nproc)
  
# 执行测试
/root/ycsb-0.17.0/bin/ycsb run mongodb \
  -P /root/ec2-test-suite/benchmark/workload_mongo \
  -p mongodb.url=${MONGO_URL} -threads 1