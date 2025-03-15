#!/bin/bash

# Redis Benchmark
# 待测 EC2 规格和 OS
os_types="al2023"


### SUT_NAME=valkey ,shein sample
instance_types="r6i.4xlarge r7g.4xlarge r8g.4xlarge r6g.4xlarge" 
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
		bash benchmark/valkey-benchmark_shein.sh ${INSTANCE_IP_MASTER} 6379
		
		## 停止实例
		aws ec2 stop-instances --region $REGION_NAME --instance-ids ${INSTANCE_ID} &
	done
done

### SUT_NAME=valkey1 ,shein sample
instance_types="r6i.4xlarge r7g.4xlarge r8g.4xlarge r6g.4xlarge" 
echo "$0: Valkey benchmark, single node..."
for os in ${os_types} 
do
	for ins in ${instance_types} 
	do
		## 创建实例、安装软件
		echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
		bash launch-instances-single.sh -s valkey1 -t ${ins} -o ${os}
		
		echo "$0: Sleep 180 seconds..."
		sleep 180
		
		## 执行 Benchmark 测试
		echo "$0: Star to run benchmark"
		source /tmp/temp-setting
		bash benchmark/valkey-benchmark_shein.sh ${INSTANCE_IP_MASTER} 6379
		
		## 停止实例
		aws ec2 stop-instances --region $REGION_NAME --instance-ids ${INSTANCE_ID} &
	done
done

### SUT_NAME=valkey, self-design sample
instance_types="r6i.2xlarge r7g.2xlarge r8g.2xlarge r6g.2xlarge" 
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
		bash benchmark/valkey-benchmark_v1.sh ${INSTANCE_IP_MASTER} 180
		
		## 停止实例
		aws ec2 stop-instances --region $REGION_NAME --instance-ids ${INSTANCE_ID} &
	done
done

echo "$0: Valkey benchmark completed."