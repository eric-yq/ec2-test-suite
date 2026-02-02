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

		# 检查启动状态
		if [ $launch_status -ne 0 ]; then
			echo "\$0: [$(date +%Y%m%d.%H%M%S)] Instance launch failed for OS_TYPE=${os}, INSTANCE_TYPE=${ins}. Continuing with next configuration..."
			continue
		fi

		# 实例类型和 IP 地址记录到文件
		source /tmp/temp-setting
		echo "${ins} ${INSTANCE_IP_MASTER}" >> /tmp/servers.txt
		
		## 停止实例
		# aws ec2 terminate-instances --instance-ids ${INSTANCE_ID} --region $(cloud-init query region) &
	done
done

echo "$0: [$(date +%Y%m%d.%H%M%S)] Sleep 30 seconds ..."
sleep 30

# 执行 ping 测试
echo "[$(date +%Y%m%d.%H%M%S)] Ping latency test ..." >> /tmp/ping_latency_log.txt
while read -r instance_type ip_address; do
do
  ping_result=$(ping -q -c 30 $ip_address | tail -n 1)
  echo "[$(date +%Y%m%d.%H%M%S)]   Instance Type: ${instance_type}, IP: $ip_address: ${ping_result}" >> /tmp/ping_latency_log.txt
done < /tmp/servers.txt
rm -f /tmp/servers.txt
