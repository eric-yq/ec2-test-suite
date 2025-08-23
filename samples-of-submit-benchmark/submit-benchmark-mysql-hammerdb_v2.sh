#!/bin/bash

set -e

## 待测 EC2 规格和 OS
os_types="al2023"
instance_types="r8g.2xlarge r8i.2xlarge r7a.2xlarge r7g.2xlarge r7i.2xlarge r6a.2xlarge r6g.2xlarge r6i.2xlarge r5.2xlarge" 
# instance_types="i8g.2xlarge"

for os in ${os_types} 
do
	for ins in ${instance_types} 
	do
		## 创建实例、安装软件
		echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
		bash launch-instances-single.sh -s mysql-ebs -t ${ins} -o ${os}
		
		echo "$0: [$(date +%Y%m%d.%H%M%S)] Sleep 180 seconds ..."
		sleep 180
		
		## 执行 Benchmark 测试
		echo "$0: Star to run benchmark"
		source /tmp/temp-setting
		
		## 准备数据
		bash benchmark/mysql-benchmark_v2_prepare.sh ${INSTANCE_IP_MASTER} 64 ${ins} 
		
		## 使用不同的vuser执行benchmark
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  1 64 ${ins} 
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  2 64 ${ins} 
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  4 64 ${ins} 
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  6 64 ${ins} 
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  8 64 ${ins} 
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 30 10 64 ${ins} 
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 30 12 64 ${ins} 
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 30 16 64 ${ins} 

		## 停止实例
		aws ec2 terminate-instances --instance-ids ${INSTANCE_ID} --region $(cloud-init query region) &
	done
done
