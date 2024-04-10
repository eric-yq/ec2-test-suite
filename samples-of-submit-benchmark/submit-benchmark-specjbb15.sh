#!/bin/bash

# 待测 EC2 规格和 OS
os_types="al2023"
instance_types="r5.4xlarge r6a.4xlarge r6g.4xlarge r6i.4xlarge r7a.4xlarge r7g.4xlarge r7i.4xlarge" 

for os in ${os_types} 
do
	for ins in ${instance_types} 
	do
		## 创建实例、安装软件
		echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
		bash launch-instances-single.sh -s specjbb15 -t ${ins} -o ${os}
	done
done
