#!/bin/bash

# Redis Benchmark
# 待测 EC2 规格和 OS
os_types="al2023"


### SUT_NAME=valkey1, not use io-threads, pipline number = 50
instance_types="r6i.xlarge r7i.xlarge r7g.xlarge r8g.xlarge r6g.xlarge" 
echo "$0: Valkey benchmark: NOT use io-threads, Pipeline number = 50 ......"
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
		bash benchmark/valkey-benchmark_shein.sh ${INSTANCE_IP_MASTER} 6379 50
		
		## 停止实例
		aws ec2 stop-instances --region $REGION_NAME --instance-ids ${INSTANCE_ID} &
	done
done

### SUT_NAME=valkey, USE io-threads with three different values, NOT use pipline
instance_types="r6i.4xlarge r7i.4xlarge r7g.4xlarge r8g.4xlarge r6g.4xlarge" 
echo "$0: Valkey benchmark: USE io-threads with three different values, NOT use pipline......"
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
		CPU_CORES=$(ssh -o StrictHostKeyChecking=no -i ~/ericyq-global.pem ec2-user@${INSTANCE_IP_MASTER} "nproc")
        
		## 测试 3 种 io-threads 模式：vCPU数量的40%、65%、90%
		let YYY=${CPU_CORES}*40/100 && let PORT=8000+$YYY
		bash benchmark/valkey-benchmark_shein.sh ${INSTANCE_IP_MASTER} ${PORT} 0
		sleep 10

		let YYY=${CPU_CORES}*65/100 && let PORT=8000+$YYY
		bash benchmark/valkey-benchmark_shein.sh ${INSTANCE_IP_MASTER} ${PORT} 0
		sleep 10

		let YYY=${CPU_CORES}*90/100 && let PORT=8000+$YYY
		bash benchmark/valkey-benchmark_shein.sh ${INSTANCE_IP_MASTER} ${PORT} 0
		sleep 10
		
		## 停止实例
		aws ec2 stop-instances --region $REGION_NAME --instance-ids ${INSTANCE_ID} &
	done
done