#!/bin/bash 

# Amazon Linux 2023
sudo su - root

# 查询所有需要挂载的本地盘
DISKS=$(lsblk -n -o NAME,TYPE,PTTYPE,PARTTYPE --list | grep disk | grep -v gpt | awk -F" " '{print $1}')
echo $DISKS

# 挂载数据盘
for disk in $DISKS
do
	echo "[INFO] Start to handle $disk..."
	# 格式化磁盘
	DEVICE=/dev/$disk
	mkfs -t xfs $DEVICE
	UUID=$(blkid | grep $disk| awk -F "\"" '{print $2}')
	
	# 创建挂载目录
	MOUNTDIR="/mnt/$disk"
	mkdir -p $MOUNTDIR
	
	# fstab 添加表项
	echo "UUID=$UUID $MOUNTDIR xfs  defaults,nofail  0  2" >> /etc/fstab
done
# cat /etc/fstab
mount -a && df -h

# 如果只使用一块 instancestore 磁盘的话，可以选用上面循环的最后一个 $disk


yum install -yq java-11-amazon-corretto java-11-amazon-corretto-devel python3-pip git
pip install dool
cd /root/
wget https://dlcdn.apache.org/kafka/3.9.0/kafka_2.13-3.9.0.tgz
tar -xzf kafka_2.13-3.9.0.tgz
cd kafka_2.13-3.9.0
 
# 修改配置文件
AAA="log.dirs=\/tmp\/kraft-combined-logs"
BBB="log.dirs=\/mnt\/$disk\/kraft-combined-logs"
# BBB="log.dirs=\/root\/kafka-data\/kraft-combined-logs"
sed -i.bak "s/$AAA/$BBB/g" config/kraft/reconfig-server.properties
sed -i "s/num.partitions=1/num.partitions=3/g" config/kraft/reconfig-server.properties
sed -i "s/localhost/$(hostname -i)/g" config/kraft/reconfig-server.properties
diff config/kraft/reconfig-server.properties*

# 初始化
KAFKA_CLUSTER_ID="$(bin/kafka-storage.sh random-uuid)"
bin/kafka-storage.sh format --standalone -t $KAFKA_CLUSTER_ID -c config/kraft/reconfig-server.properties

# 启动
nohup bin/kafka-server-start.sh config/kraft/reconfig-server.properties &

# 停止
# bin/kafka-server-stop.sh

# 创建 Topic 
bin/kafka-topics.sh --create   --topic quickstart-events --bootstrap-server localhost:9092
bin/kafka-topics.sh --describe --topic quickstart-events --bootstrap-server localhost:9092
## 如果远程连接，使用 broker-ip 替换 localhost

########################################################################################################
## Benchmark ， Producer
="172.31.47.75"  # i3.2xlarge，
BROKER_IPADDR="172.31.41.71"  # i4i.2xlarge，
BROKER_IPADDR="172.31.45.2"   # i7ie.2xlarge，
BROKER_IPADDR="172.31.44.179" # i4g.2xlarge，
BROKER_IPADDR="172.31.38.141" # i8g.2xlarge，

SIZE=300
for i in $(seq 1 3)
do 
	bin/kafka-producer-perf-test.sh --topic kafka-test --num-records 50000000 --throughput -1 --record-size $SIZE --producer-props bootstrap.servers=$BROKER_IPADDR:9092 acks=1
	sleep 5
done

########################################################################################################
## Benchmark ， Consumer
BROKER_IPADDR="172.31.47.75"  # i3.2xlarge，
BROKER_IPADDR="172.31.41.71"  # i4i.2xlarge，
BROKER_IPADDR="172.31.45.2"   # i7ie.2xlarge，
BROKER_IPADDR="172.31.44.179" # i4g.2xlarge，
BROKER_IPADDR="172.31.38.141" # i8g.2xlarge，

for i in $(seq 1 3)
do 
	bin/kafka-consumer-perf-test.sh --topic kafka-test --threads 4 --messages 50000000  --broker-list $BROKER_IPADDR:9092
	sleep 5
done

########################################################################################################
# 删除 topics
.bin/kafka-topics.sh --bootstrap-server $BROKER_IPADDR:9092 --delete --topic kafka-test