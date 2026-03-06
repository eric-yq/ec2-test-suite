# 操作
## YCSB workload 文件 
cat << EOF > /root/ycsb-0.17.0/workloads/mongo-env.properties
mongodb.url=mongodb://127.0.0.1:27017/ycsb?w=1
recordcount=48000000
operationcount=48000000
fieldcount=10
fieldlength=100
workload=site.ycsb.workloads.CoreWorkload
threadcount=64
EOF

## r8g集群
export N1=172.31.35.156 
export N2=172.31.32.253
export N3=172.31.45.238
export MONGO_URL="mongodb://$N1:27017,$N2:27017,$N3:27017/ycsb"
echo $MONGO_URL

## r7i集群
export N1=172.31.44.186 
export N2=172.31.32.65
export N3=172.31.44.200
export MONGO_URL="mongodb://$N1:27017,$N2:27017,$N3:27017/ycsb"
echo $MONGO_URL


## 加载数据
./bin/ycsb.sh load mongodb -s \
  -P workloads/mongo-env.properties \
  -p mongodb.url="${MONGO_URL}" \
  -p mongodb.writeConcern=acknowledged \
  -p requestdistribution=zipfian \
  -threads 16

## 读负载测试
./bin/ycsb.sh run mongodb -s \
  -P workloads/mongo-env.properties \
  -p mongodb.url="${MONGO_URL}" \
  -p mongodb.writeConcern=acknowledged \
  -p readproportion=0.95 \
  -p updateproportion=0.05 \
  -p requestdistribution=zipfian \
  -p maxexecutiontime=3600 \
  -threads 64
   
## 写负载测试
./bin/ycsb.sh run mongodb -s \
  -P workloads/mongo-env.properties \
  -p mongodb.url="${MONGO_URL}" \
  -p mongodb.writeConcern=acknowledged \
  -p readproportion=0.10 \
  -p updateproportion=0.90 \
  -p requestdistribution=uniform \
  -p maxexecutiontime=3600 \
  -threads 64
  
## 监控
sudo apt install python3-pip -y
pip3 install dool --break-system-packages
sudo ln -s /home/ubuntu/.local/bin/dool /usr/local/bin/dool 
dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60
