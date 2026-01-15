#!/bin/bash

# qdrant Benchmark
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
		eval $OPT bash launch-instances-single.sh -s qdrant -t ${ins} -o ${os}
		
		echo "$0: [$(date +%Y%m%d.%H%M%S)] Sleep 300 seconds..."
		sleep 120
		
		## 执行 Benchmark 测试
		echo "$0: Star to run benchmark"
		source /tmp/temp-setting
		bash benchmark/qdrant-benchmark.sh ${INSTANCE_IP_MASTER}
		
		## 停止实例
		# aws ec2 stop-instances --instance-ids ${INSTANCE_ID}
	done
done
