#!/bin/bash

# Redis Benchmark
# 待测 EC2 规格和 OS
os_types="al2023"
instance_types="r6g.xlarge r6i.xlarge r7g.xlarge r7i.xlarge r8g.xlarge r6g.2xlarge r6i.2xlarge r7g.2xlarge r7i.2xlarge r8g.2xlarge" 


echo "$0: Valkey benchmark, single node..."
for os in ${os_types} 
do
	for ins in ${instance_types} 
	do
		## 创建实例、安装软件
		echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
		bash launch-instances-single.sh -s valkey -t ${ins} -o ${os}
		
		echo "$0: Sleep 180 seconds..."
		sleep 180
		
		## 执行 Benchmark 测试
		echo "$0: Star to run benchmark"
		source /tmp/temp-setting
		bash benchmark/valkey-benchmark_zhangkai.sh ${INSTANCE_IP_MASTER} 120
		
		## 停止实例
		aws ec2 terminate-instances --region $REGION_NAME --instance-ids ${INSTANCE_ID} &
	done
done

echo "$0: Valkey benchmark, cluster ..."
for os in ${os_types} 
do
	for ins in ${instance_types} 
	do
		## 创建实例、安装软件
		echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
		bash launch-instances-cluster.sh -s valkey-cluster -t ${ins} -o ${os}

# 		echo "$0: Sleep 180 seconds..."
# 		sleep 180

		## 执行 Benchmark 测试
		echo "$0: Star to run benchmark"
		source /tmp/temp-setting
		bash benchmark/valkey-benchmark_zhangkai.sh ${INSTANCE_IP_MASTER} 120
		
		## 停止实例
		aws ec2 terminate-instances --region $REGION_NAME --instance-ids \
		  ${INSTANCE_ID_MASTER} ${INSTANCE_ID_MASTER1} ${INSTANCE_ID_MASTER2} \
		  ${INSTANCE_ID_SLAVE} ${INSTANCE_ID_SLAVE1} ${INSTANCE_ID_SLAVE2} &
	done
done

echo "$0: Valkey benchmark completed."
