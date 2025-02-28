#!/bin/bash

set -e

source /tmp/temp-setting
source /etc/profile

setup_redis_cluster(){
	# 建立 3主3从 Redis 集群
	echo "yes" | redis-cli --cluster create  \
      ${INSTANCE_IP_MASTER}:6379 ${INSTANCE_IP_MASTER1}:6379 ${INSTANCE_IP_MASTER2}:6379 \
      ${INSTANCE_IP_SLAVE}:6379 ${INSTANCE_IP_SLAVE1}:6379 ${INSTANCE_IP_SLAVE2}:6379 \
      --cluster-replicas 1 
    
    sleep 10
    
	# 查看集群信息
	redis-cli -h ${INSTANCE_IP_MASTER} cluster info
}

setup_valkey_cluster(){
	# 建立 3主3从 Valkey 集群
# 	echo "yes" | docker exec -it valkey valkey-cli --cluster create  \
#       ${INSTANCE_IP_MASTER}:6379 ${INSTANCE_IP_MASTER1}:6379 ${INSTANCE_IP_MASTER2}:6379 \
#       ${INSTANCE_IP_SLAVE}:6379 ${INSTANCE_IP_SLAVE1}:6379 ${INSTANCE_IP_SLAVE2}:6379 \
#       --cluster-replicas 1 

    echo "yes" | valkey-cli --cluster create  \
        ${INSTANCE_IP_MASTER}:6379 ${INSTANCE_IP_MASTER1}:6379 ${INSTANCE_IP_MASTER2}:6379 \
        ${INSTANCE_IP_SLAVE}:6379 ${INSTANCE_IP_SLAVE1}:6379 ${INSTANCE_IP_SLAVE2}:6379 \
        --cluster-replicas 1 
    
    sleep 10
    
	# 查看集群信息
# 	docker exec -it valkey valkey-cli -h ${INSTANCE_IP_MASTER} cluster info
    valkey-cli -h ${INSTANCE_IP_MASTER} cluster info
}

setup_kafka_cluster(){
	# 建立 3节点 Kafka 集群
	UUID=$(kafka-storage.sh random-uuid)
	chmod 400 ./${KEY_NAME}.pem
	cat << EOF > remote.sh
## 修改配置
sudo sed -i "s/controller.quorum.voters=1@localhost:9093/controller.quorum.voters=${NODEID}@${INSTANCE_IP_MASTER}:9093,${NODEID1}@${INSTANCE_IP_MASTER1}:9093,${NODEID2}@${INSTANCE_IP_MASTER2}:9093/g" /root/kafka_2.12-3.3.1/config/kraft/server.properties 
sudo /root/kafka_2.12-3.3.1/bin/kafka-storage.sh format -t ${UUID} -c /root/kafka_2.12-3.3.1/config/kraft/server.properties
## 启动节点
sudo /root/kafka_2.12-3.3.1/bin/kafka-server-start.sh -daemon /root/kafka_2.12-3.3.1/config/kraft/server.properties
sudo jps
exit
EOF
	for ipaddr in ${INSTANCE_IP_MASTER} ${INSTANCE_IP_MASTER1} ${INSTANCE_IP_MASTER2}
	do
		echo ">>> start to modify kafka config on ${ipaddr}."
		ssh -i ./${KEY_NAME}.pem -o "StrictHostKeyChecking no" ec2-user@${ipaddr} < remote.sh
	done
}

setup_cassandra_cluster(){
# 建立 3节点 Cassandra 集群
    echo "Not supported now."
}


## 主流程
echo "$0: Start to setup Cluster......"

if   [[ "$SUT_NAME" == "redis-cluster" ]] ; then

	setup_redis_cluster
	
elif [[ "$SUT_NAME" == "valkey-cluster" ]]; then

	setup_valkey_cluster

elif [[ "$SUT_NAME" == "kafka-cluster" ]]; then

	setup_kafka_cluster
		
elif [[ "$SUT_NAME" == "cassandra-cluster" ]]; then

	setup_cassandra_cluster

else
	echo "$0: No need to perform additional setup."
	exit 1
fi
