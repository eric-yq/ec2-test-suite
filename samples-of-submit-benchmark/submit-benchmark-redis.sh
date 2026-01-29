#!/bin/bash

# Redis Benchmark
# 待测 EC2 规格和 OS
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
		eval $OPT bash launch-instances-single.sh -s redis -t ${ins} -o ${os}
		# 检查实例启动状态：如果失败则跳过后续测试。
		launch_status=$?
		if [ $launch_status -ne 0 ]; then
			echo "\$0: [$(date +%Y%m%d.%H%M%S)] Instance launch failed for OS_TYPE=${os}, INSTANCE_TYPE=${ins}. Continuing with next configuration..."
			continue
		fi
		
		echo "$0: [$(date +%Y%m%d.%H%M%S)] Sleep 180 seconds..."
		sleep 180
		
		## 执行 Benchmark 测试
		echo "$0: Star to run benchmark"
		source /tmp/temp-setting
		bash benchmark/redis-benchmark_v1.sh ${INSTANCE_IP_MASTER} 6379 180
		# bash benchmark/redis-benchmark_v1.sh ${INSTANCE_IP_MASTER} 8003 180
		bash benchmark/redis-benchmark_v1.sh ${INSTANCE_IP_MASTER} 8005 180
		# bash benchmark/redis-benchmark_v1.sh ${INSTANCE_IP_MASTER} 8007 180
		
		# 停止 dool 监控
		sleep 10 && killall ssh dool

		## 停止实例
		aws ec2 terminate-instances --instance-ids ${INSTANCE_ID} --region $(cloud-init query region) &
	done
done

echo "$0: Redis benchmark completed."
