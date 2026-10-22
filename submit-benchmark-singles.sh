#!/bin/bash

# 待测 EC2 规格和 OS
os_types="al2023"
sut_name="$1"  ## specjbb15, ffmpeg, spark, pts, pts_ssd
instance_types="$2"

for os in ${os_types} 
do
	for ins in ${instance_types} 
	do
		## 创建实例、安装软件
		echo "$0: SUT_NAME=${sut_name}, OS_TYPE=${os}, INSTANCE_TYPE=${ins} ..."
		bash launch-instances-single.sh -s ${sut_name} -t ${ins} -o ${os}
	done
done
