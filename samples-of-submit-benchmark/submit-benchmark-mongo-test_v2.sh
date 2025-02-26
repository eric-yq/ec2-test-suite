#!/bin/bash

# qdrant Benchmark
os_types="al2023"
# instance_types="m7a.2xlarge m7i.2xlarge m7g.2xlarge m6a.2xlarge m6g.2xlarge m6i.2xlarge m5.2xlarge"
instance_types="r8g.2xlarge"

for os in ${os_types} 
do
	for ins in ${instance_types} 
	do
		## 创建实例、安装软件
		echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
		bash launch-instances-single.sh -s mongo -t ${ins} -o ${os}
		
		echo "$0: Sleep 300 seconds..."
		sleep 300
		
		## 执行 Benchmark 测试
		echo "$0: Star to run benchmark"
		source /tmp/temp-setting
		bash benchmark/mongo-benchmark_v2.sh ${INSTANCE_IP_MASTER}
		
		## 停止实例
		## aws ec2 stop-instances --instance-ids ${INSTANCE_ID}
	done
done



echo "$0: Qdrant benchmark completed."
