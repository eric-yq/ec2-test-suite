#!/bin/bash

# 待测 EC2 规格和 OS
os_types="al2023"
# instance_types="r8a.2xlarge r8g.2xlarge r8i.2xlarge r7a.2xlarge r7g.2xlarge r7i.2xlarge r6a.2xlarge r6g.2xlarge r6i.2xlarge"
instance_types="m8a.2xlarge m8g.2xlarge m8i.2xlarge m7a.2xlarge m7g.2xlarge m7i.2xlarge m6a.2xlarge m6g.2xlarge m6i.2xlarge"

for os in ${os_types} 
do
	for ins in ${instance_types} 
	do
		## 创建实例、安装软件
		echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
		bash launch-instances-single.sh -s specjbb15 -t ${ins} -o ${os}
		bash launch-instances-single.sh -s ffmpeg    -t ${ins} -o ${os}
		# bash launch-instances-single.sh -s spark     -t ${ins} -o ${os}
		# bash launch-instances-single.sh -s pts       -t ${ins} -o ${os}

	done
done
