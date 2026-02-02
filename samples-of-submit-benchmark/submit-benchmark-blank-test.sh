#!/bin/bash

set -e

## 待测 EC2 规格和 OS
os_types="al2023"
instance_types="$1"

if [ "$USE_CPG" = "1" ] ; then
  OPT="USE_CPG=1"
else
  OPT=""
fi

for os in ${os_types} 
do
	for ins in ${instance_types} 
	do
		## 创建实例、安装软件
		echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
		eval $OPT bash launch-instances-single.sh -s blank -t ${ins} -o ${os}
		launch_status=$?

		检查启动状态
		if [ $launch_status -ne 0 ]; then
			echo "\$0: [$(date +%Y%m%d.%H%M%S)] Instance launch failed for OS_TYPE=${os}, INSTANCE_TYPE=${ins}. Continuing with next configuration..."
			continue
		fi

		source /tmp/temp-setting
		echo "$0: [$(date +%Y%m%d.%H%M%S)] Sleep 30 seconds ..."
		sleep 30

		# 执行 ping 测试
		PING_RESULT=$(ping -q -c 30 ${INSTANCE_IP_MASTER} | tail -n 1)
		echo "[$(date +%Y%m%d.%H%M%S)] Instance Type: ${ins}, IP: ${INSTANCE_IP_MASTER}: ${PING_RESULT}" >> /tmp/ping_latency_log.txt

		## 停止实例
		# aws ec2 terminate-instances --instance-ids ${INSTANCE_ID} --region $(cloud-init query region) &
	done
done
