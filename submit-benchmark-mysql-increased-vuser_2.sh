#!/bin/bash

## 保存结果的目录
mkdir -p $0--result-summary

## 待测 EC2 规格和 OS
os_types="al2"
# instance_types="m7a.2xlarge m7g.2xlarge m7i.2xlarge m6a.2xlarge m6g.2xlarge m6i.2xlarge m5.2xlarge"
instance_types="m5.2xlarge m6"

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
		
# 		bash benchmark/mysql-benchmark_v2.sh ${INSTANCE_IP_MASTER} 60  1 32
# 		bash benchmark/mysql-benchmark_v2.sh ${INSTANCE_IP_MASTER} 60  2 32
		bash benchmark/mysql-benchmark_v2.sh ${INSTANCE_IP_MASTER} 60  4 32
# 		bash benchmark/mysql-benchmark_v2.sh ${INSTANCE_IP_MASTER} 60  6 32
# 		bash benchmark/mysql-benchmark_v2.sh ${INSTANCE_IP_MASTER} 60  8 32
# 		bash benchmark/mysql-benchmark_v2.sh ${INSTANCE_IP_MASTER} 60 10 32
# 		bash benchmark/mysql-benchmark_v2.sh ${INSTANCE_IP_MASTER} 60 12 32
# 		bash benchmark/mysql-benchmark_v2.sh ${INSTANCE_IP_MASTER} 60 14 32
# 		bash benchmark/mysql-benchmark_v2.sh ${INSTANCE_IP_MASTER} 60 16 32
		
		## 停止实例
		aws ec2 stop-instances --instance-ids ${INSTANCE_ID} 
	done
done

