#!/bin/bash

# Redis Benchmark
# 待测 EC2 规格和 OS
os_types="al2023"
instance_types="r8g.2xlarge r7a.2xlarge r7g.2xlarge r7i.2xlarge r6a.2xlarge r6g.2xlarge r6i.2xlarge" 

for os in ${os_types} 
do
	for ins in ${instance_types} 
	do
		## 创建实例、安装软件
		echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
		bash launch-instances-cluster.sh -s valkey-cluster -t ${ins} -o ${os}

		echo "$0: Sleep 120 seconds..."
		sleep 120

		## 执行 Benchmark 测试
		echo "$0: Star to run benchmark"
		source /tmp/temp-setting
		bash benchmark/valkey-benchmark_v1.sh ${INSTANCE_IP_MASTER} 180
		
		## 停止实例
		aws ec2 terminate-instances --region $REGION_NAME --instance-ids \
		  ${INSTANCE_ID_MASTER} ${INSTANCE_ID_MASTER1} ${INSTANCE_ID_MASTER2} \
		  ${INSTANCE_ID_SLAVE} ${INSTANCE_ID_SLAVE1} ${INSTANCE_ID_SLAVE2}
	done
done

echo "$0: Valkey benchmark completed."