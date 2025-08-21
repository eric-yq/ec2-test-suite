#!/bin/bash

# 待测 EC2 规格和 OS
os_types="al2023"
instance_types="r8i.2xlarge r8g.2xlarge r7a.2xlarge r7g.2xlarge r7i.2xlarge r6a.2xlarge r6g.2xlarge r6i.2xlarge r5.2xlarge"


for os in ${os_types} 
do
	for ins in ${instance_types} 
		do
		## 创建实例、安装软件
		echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
		bash launch-instances-nginx.sh -s nginx -t ${ins} -o ${os}

		## 执行 Benchmark 测试
		echo "$0: Star to run benchmark"
		source /tmp/temp-setting
		bash benchmark/nginx-benchmark.sh ${INSTANCE_IP_LOADBALANCE}
		
		## 停止实例
		aws ec2 terminate-instances --region $REGION_NAME --instance-ids \
		  ${INSTANCE_ID_LOADBALANCE} ${INSTANCE_ID_WEB1} ${INSTANCE_ID_WEB2} &
	done
done
