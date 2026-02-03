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
		sleep 120
	    ####################################

		## 执行 Benchmark 测试
		echo "$0: Star to run benchmark"
		source /tmp/temp-setting

		## 准备数据
	    bash benchmark/mysql-benchmark_sysbench_prepare.sh ${INSTANCE_IP_MASTER} 60  15 20000000
		## 数据量估算：15 个表，每个表 20000000 条记录，数据库中大小约 68,756 MB 数据
		# [Build Schema Summary]: 
		# 数据库  记录数      数据容量(MB)  索引容量(MB)
		# oltp   294912656  64290.00     4466.85

		## 使用不同的 “线程数+时间“ 的组合，执行 benchmark
		bash benchmark/mysql-benchmark_sysbench_run.sh ${INSTANCE_IP_MASTER} 30  15 20000000 2
		bash benchmark/mysql-benchmark_sysbench_run.sh ${INSTANCE_IP_MASTER} 30  15 20000000 4
		bash benchmark/mysql-benchmark_sysbench_run.sh ${INSTANCE_IP_MASTER} 60  15 20000000 6
		bash benchmark/mysql-benchmark_sysbench_run.sh ${INSTANCE_IP_MASTER} 60  15 20000000 8
		bash benchmark/mysql-benchmark_sysbench_run.sh ${INSTANCE_IP_MASTER} 60  15 20000000 10
		bash benchmark/mysql-benchmark_sysbench_run.sh ${INSTANCE_IP_MASTER} 30  15 20000000 12
		bash benchmark/mysql-benchmark_sysbench_run.sh ${INSTANCE_IP_MASTER} 30  15 20000000 16
		bash benchmark/mysql-benchmark_sysbench_run.sh ${INSTANCE_IP_MASTER} 15  15 20000000 20
		bash benchmark/mysql-benchmark_sysbench_run.sh ${INSTANCE_IP_MASTER} 15  15 20000000 24
		bash benchmark/mysql-benchmark_sysbench_run.sh ${INSTANCE_IP_MASTER} 15  15 20000000 28
		bash benchmark/mysql-benchmark_sysbench_run.sh ${INSTANCE_IP_MASTER} 15  15 20000000 32

		# 停止 dool 监控
		sleep 10 && killall ssh dool
		
		## 停止实例	
		aws ec2 terminate-instances --instance-ids ${INSTANCE_ID} --region $(cloud-init query region) &
	done
done

