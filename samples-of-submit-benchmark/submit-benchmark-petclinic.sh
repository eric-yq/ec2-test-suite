#!/bin/bash

set -e

## 待测 EC2 规格和 OS
os_types="al2023"
instance_types="r8g.2xlarge r8i.2xlarge r7a.2xlarge r7g.2xlarge r7i.2xlarge r6a.2xlarge r6g.2xlarge r6i.2xlarge" 
# instance_types="r8g.2xlarge" 


for os in ${os_types} 
do
	for ins in ${instance_types} 
	do
		## 创建实例、安装软件
		echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
		bash launch-instances-single.sh -s sprintboot-petclinic -t ${ins} -o ${os}
		launch_status=$?

		# 检查启动状态
		if [ $launch_status -ne 0 ]; then
			echo "\$0: [$(date +%Y%m%d.%H%M%S)] Instance launch failed for OS_TYPE=${os}, INSTANCE_TYPE=${ins}. Continuing with next configuration..."
			continue
		fi

		echo "$0: [$(date +%Y%m%d.%H%M%S)] Sleep 300 seconds ..."
		sleep 300

		## 执行 Benchmark 测试
		echo "$0: Star to run benchmark"
		source /tmp/temp-setting

		## 使用不同的user执行benchmark
		bash benchmark/petclinic-benchmark.sh ${INSTANCE_IP_MASTER} 30
        bash benchmark/petclinic-benchmark.sh ${INSTANCE_IP_MASTER} 60
        bash benchmark/petclinic-benchmark.sh ${INSTANCE_IP_MASTER} 90
		bash benchmark/petclinic-benchmark.sh ${INSTANCE_IP_MASTER} 120
        bash benchmark/petclinic-benchmark.sh ${INSTANCE_IP_MASTER} 150
        bash benchmark/petclinic-benchmark.sh ${INSTANCE_IP_MASTER} 200

		## 停止实例
		aws ec2 stop-instances --instance-ids ${INSTANCE_ID} --region $(cloud-init query region) &
	done
done
