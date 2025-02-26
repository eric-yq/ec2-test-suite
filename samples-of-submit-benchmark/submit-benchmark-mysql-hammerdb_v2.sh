#!/bin/bash

## 待测 EC2 规格和 OS
os_types="al2023"
instance_types="i8g.2xlarge"

for os in ${os_types} 
do
	for ins in ${instance_types} 
	do
		## 创建实例、安装软件
		echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
		bash launch-instances-single.sh -s mysql -t ${ins} -o ${os}
		
		echo "$0: Sleep 180 seconds..."
		sleep 180
		
		## 执行 Benchmark 测试
		echo "$0: Star to run benchmark"
		source /tmp/temp-setting
		
		## 准备数据
		bash benchmark/mysql-benchmark_v2_prepare.sh ${INSTANCE_IP_MASTER} 100
		
		## 使用不同的vuser执行benchmark
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60 1 100

		## 停止实例
		# aws ec2 stop-instances --instance-ids ${INSTANCE_ID} 
	done
done

