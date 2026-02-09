#!/bin/bash

# 待测 EC2 规格和 OS
os_types="al2023"
instance_types="$1"

## CPG 选项
if [ "$USE_CPG" = "1" ] ; then
  OPT="USE_CPG=1"
else
  OPT="USE_CPG=0"
fi

# 清理临时文件
rm -rf /tmp/servers.txt /tmp/ping_latency_log.txt

for os in ${os_types} 
do
	for ins in ${instance_types} 
	do
		## 创建实例、安装软件
		echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
		eval $OPT bash launch-instances-single.sh -s milvus -t ${ins} -o ${os}
		# 检查实例启动状态：如果失败则跳过后续测试。
		launch_status=$?
		if [ $launch_status -ne 0 ]; then
			echo "\$0: [$(date +%Y%m%d.%H%M%S)] Instance launch failed for OS_TYPE=${os}, INSTANCE_TYPE=${ins}. Continuing with next configuration..."
			continue
		fi

		####################################
		# 实例类型、IP 地址和实例 ID 记录到文件
		source /tmp/temp-setting
		echo "${ins} ${INSTANCE_IP_MASTER} ${INSTANCE_ID}" >> /tmp/servers.txt
		echo "[$(date +%Y%m%d.%H%M%S)] Sleep 30 seconds ..." && sleep 30
		# 执行 ping 测试
		echo "[$(date +%Y%m%d.%H%M%S)] Ping latency test, result shows the avg. latency only. Extra option : ${OPT}"
		ping_result=$(ping -q -c 60 ${INSTANCE_IP_MASTER} | tail -n 1 | awk -F '/' '{print $5 " ms"}') 
		echo "[$(date +%Y%m%d.%H%M%S)]   ${ins}, ${INSTANCE_IP_MASTER} : ${ping_result}"
		sleep 120
	    ####################################

		## 执行 Benchmark 测试
		echo "$0: Star to run benchmark"
		bash benchmark/milvus-benchmark.sh ${INSTANCE_IP_MASTER}
		
		# 停止 dool 监控
		sleep 10 && killall ssh dool
		
		## 停止实例
		aws ec2 terminate-instances --instance-ids ${INSTANCE_ID} --region $(ec2-metadata --quiet --region) &
	done
done

echo "$0: Milvus benchmark completed."
