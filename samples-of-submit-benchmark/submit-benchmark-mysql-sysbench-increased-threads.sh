#!/bin/bash

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
		$OPT bash launch-instances-single.sh -s mysql-ebs -t ${ins} -o ${os}
		launch_status=$?

		# 检查启动状态
		if [ $launch_status -ne 0 ]; then
			echo "\$0: [$(date +%Y%m%d.%H%M%S)] Instance launch failed for OS_TYPE=${os}, INSTANCE_TYPE=${ins}. Continuing with next configuration..."
			continue
		fi

		echo "$0: [$(date +%Y%m%d.%H%M%S)] Sleep 600 seconds ..."
		sleep 600

		## 执行 Benchmark 测试
		echo "$0: Star to run benchmark"
		source /tmp/temp-setting

		## 准备数据
		bash benchmark/mysql-benchmark_sysbench_prepare.sh ${INSTANCE_IP_MASTER} 60  9 20000000

		## 使用不同的线程数执行benchmark
		bash benchmark/mysql-benchmark_sysbench_run.sh ${INSTANCE_IP_MASTER} 60  9 20000000 1
		bash benchmark/mysql-benchmark_sysbench_run.sh ${INSTANCE_IP_MASTER} 60  9 20000000 2
		bash benchmark/mysql-benchmark_sysbench_run.sh ${INSTANCE_IP_MASTER} 60  9 20000000 4
		bash benchmark/mysql-benchmark_sysbench_run.sh ${INSTANCE_IP_MASTER} 60  9 20000000 6
		bash benchmark/mysql-benchmark_sysbench_run.sh ${INSTANCE_IP_MASTER} 60  9 20000000 8
		bash benchmark/mysql-benchmark_sysbench_run.sh ${INSTANCE_IP_MASTER} 30  9 20000000 10
		bash benchmark/mysql-benchmark_sysbench_run.sh ${INSTANCE_IP_MASTER} 30  9 20000000 12
		bash benchmark/mysql-benchmark_sysbench_run.sh ${INSTANCE_IP_MASTER} 30  9 20000000 16

		## 停止实例
		aws ec2 terminate-instances --instance-ids ${INSTANCE_ID} --region $(cloud-init query region) &
	done
done

