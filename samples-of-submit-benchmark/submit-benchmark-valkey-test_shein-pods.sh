#!/bin/bash

# Redis Benchmark
# 待测 EC2 规格和 OS
os_types="al2023"
instance_types="r6i.4xlarge r7g.4xlarge r8g.4xlarge r6g.4xlarge" 

echo "$0: Valkey benchmark, single node..."
for os in ${os_types} 
do
	for ins in ${instance_types} 
	do
		## 创建实例、安装软件
		echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
		bash launch-instances-single.sh -s valkey-pods -t ${ins} -o ${os}
		
		echo "$0: Sleep 180 seconds..."
		sleep 180
		
		## 执行 Benchmark 测试
		echo "$0: Star to run benchmark"
		source /tmp/temp-setting
		
		let PODS_NUMBER=${INSTANCE_VCPU_NUM}*75/10
		echo "$0: Start to run Valkey benchmark on: ${ins}(${INSTANCE_IP_MASTER})..."
		for i in $(seq 1 $PODS_NUMBER)
		do
		    let PORT=${i}+8880
		    nohup bash benchmark/valkey-benchmark_shein-pods.sh ${INSTANCE_IP_MASTER} ${PORT} &
		done
		
		# 等待所有后台进程结束
		wait
		echo "$0: Valkey benchmark completed on: ${ins}(${INSTANCE_IP_MASTER})."
		
		## 停止实例
		# aws ec2 terminate-instances --region $REGION_NAME --instance-ids ${INSTANCE_ID} &
	done
done

echo "$0: Valkey benchmark completed on all: ${instance_types}."