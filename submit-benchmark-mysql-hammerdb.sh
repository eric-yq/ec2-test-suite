#!/bin/bash

set -e

## 待测 EC2 规格和 OS
os_types="al2023"
instance_types="$1"
# instance_types="r8a.2xlarge r8g.2xlarge r8i.2xlarge r7a.2xlarge r7g.2xlarge r7i.2xlarge r6a.2xlarge r6g.2xlarge r6i.2xlarge"
# instance_types="m8a.2xlarge m8g.2xlarge m8i.2xlarge m7a.2xlarge m7g.2xlarge m7i.2xlarge m6a.2xlarge m6g.2xlarge m6i.2xlarge"

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
		eval $OPT bash launch-instances-single.sh -s mysql-ebs -t ${ins} -o ${os}
		launch_status=$?

		# 检查启动状态
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
		echo "[$(date +%Y%m%d.%H%M%S)] Sleep 120 seconds before benchmark test..." && sleep 120
	    ####################################
		
		## 执行 Benchmark 测试
		echo "[$(date +%Y%m%d.%H%M%S)] Star to run benchmark"
		source /tmp/temp-setting

		## 准备数据
		bash benchmark/mysql-benchmark_v2_prepare.sh ${INSTANCE_IP_MASTER} 64 ${ins} 

		## 使用不同的vuser执行benchmark
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  1 64 ${ins} 
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  2 64 ${ins} 
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  4 64 ${ins} 
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  6 64 ${ins} 
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  8 64 ${ins} 
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 30 10 64 ${ins} 
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 30 12 64 ${ins} 
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 30 16 64 ${ins} 

		# 停止 dool 监控
		sleep 10 && killall ssh dool
		
		## 停止实例
		aws ec2 terminate-instances --instance-ids ${INSTANCE_ID} --region $(ec2-metadata --quiet --region) &
	done
done
