#!/bin/bash

# 待测 EC2 规格和 OS
os_types="al2023"
sut_name="$1"  ## specjbb15, ffmpeg, spark, pts
instance_types="$2"

# instance_types="r8a.2xlarge r8g.2xlarge r8i.2xlarge r7a.2xlarge r7g.2xlarge r7i.2xlarge r6a.2xlarge r6g.2xlarge r6i.2xlarge"
instance_types="m9g.4xlarge m8a.4xlarge m8g.4xlarge m8i.4xlarge m7a.4xlarge m7g.4xlarge m7i.4xlarge m6a.4xlarge m6g.4xlarge m6i.4xlarge"

for os in ${os_types} 
do
	for ins in ${instance_types} 
	do
		## 创建实例、安装软件
		echo "$0: SUT_NAME=${sut_name}, OS_TYPE=${os}, INSTANCE_TYPE=${ins} ..."
		bash launch-instances-single.sh -s ${sut_name} -t ${ins} -o ${os}
	done
done
