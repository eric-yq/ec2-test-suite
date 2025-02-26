#!/bin/bash

## 待测 EC2 规格和 OS
os_types="al2023"
instance_types="r5.2xlarge r6a.2xlarge r6g.2xlarge r6i.2xlarge r7a.2xlarge r7g.2xlarge r7i.2xlarge"
# instance_types="r5.2xlarge"	

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
		
		bash benchmark/mysql-benchmark_v2.sh ${INSTANCE_IP_MASTER} 60  1 64
		bash benchmark/mysql-benchmark_v2.sh ${INSTANCE_IP_MASTER} 60  2 64
	    bash benchmark/mysql-benchmark_v2.sh ${INSTANCE_IP_MASTER} 60  4 64
		bash benchmark/mysql-benchmark_v2.sh ${INSTANCE_IP_MASTER} 60  6 64
		bash benchmark/mysql-benchmark_v2.sh ${INSTANCE_IP_MASTER} 60  8 64
		bash benchmark/mysql-benchmark_v2.sh ${INSTANCE_IP_MASTER} 60 10 64
		bash benchmark/mysql-benchmark_v2.sh ${INSTANCE_IP_MASTER} 60 12 64
		bash benchmark/mysql-benchmark_v2.sh ${INSTANCE_IP_MASTER} 60 16 64
		
		## 停止实例
		aws ec2 stop-instances --instance-ids ${INSTANCE_ID} 
	done
done

