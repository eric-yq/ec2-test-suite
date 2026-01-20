#!/bin/bash

## JD 在 20260120 提供的测试报告中：
## 数据量采用 100*1M(约 23GB）， 实例size 为 m7i.4xlarge(16 vCPU, 64 GiB)
## 补充测试时，数据量采用 100*3M

# 待测 EC2 规格和 OS
os_types="al2023"
instance_types="$1"

# 是否采用 Cluster Placement Group 启动实例
if [ "$USE_CPG" = "1" ] ; then
  OPT="USE_CPG=1"
else
  OPT=""
fi

## 测试 1： JD 提供的数据量；
# 测试参数
SUT_IP_ADDR=${INSTANCE_IP_MASTER}
OLTP_DURATION=10
TABLES=100
TABLE_SIZE=1000000

for os in ${os_types} 
do
	for ins in ${instance_types} 
	do
		## 创建实例、安装软件
		echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
		eval $OPT bash launch-instances-single.sh -s mysql-jd -t ${ins} -o ${os}
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
	    bash benchmark/mysql-benchmark_sysbench_prepare.sh ${SUT_IP_ADDR} ${OLTP_DURATION} ${TABLES} ${TABLE_SIZE}
		## 数据量估算：15 个表，每个表 20000000 条记录，数据库中大小约 68,756 MB 数据
		# [Build Schema Summary]: 
		# 数据库  记录数      数据容量(MB)  索引容量(MB)
		# oltp   294912656  64290.00     4466.85

		## 使用不同的 “线程数+时间“ 的组合，执行 benchmark
		# 精简并发: 低/中/高/极端
		THREADS="4 32 128 512"
		for t in ${THREADS}
		do
		    bash benchmark/mysql-benchmark_sysbench_run-jd.sh ${SUT_IP_ADDR} ${OLTP_DURATION} ${TABLES} ${TABLE_SIZE} ${t} read_only
			bash benchmark/mysql-benchmark_sysbench_run-jd.sh ${SUT_IP_ADDR} ${OLTP_DURATION} ${TABLES} ${TABLE_SIZE} ${t} write_only
			bash benchmark/mysql-benchmark_sysbench_run-jd.sh ${SUT_IP_ADDR} ${OLTP_DURATION} ${TABLES} ${TABLE_SIZE} ${t} rw_default
			bash benchmark/mysql-benchmark_sysbench_run-jd.sh ${SUT_IP_ADDR} ${OLTP_DURATION} ${TABLES} ${TABLE_SIZE} ${t} rw_70_30
			bash benchmark/mysql-benchmark_sysbench_run-jd.sh ${SUT_IP_ADDR} ${OLTP_DURATION} ${TABLES} ${TABLE_SIZE} ${t} rw_90_10
			bash benchmark/mysql-benchmark_sysbench_run-jd.sh ${SUT_IP_ADDR} ${OLTP_DURATION} ${TABLES} ${TABLE_SIZE} ${t} point_select
			bash benchmark/mysql-benchmark_sysbench_run-jd.sh ${SUT_IP_ADDR} ${OLTP_DURATION} ${TABLES} ${TABLE_SIZE} ${t} update_index
			bash benchmark/mysql-benchmark_sysbench_run-jd.sh ${SUT_IP_ADDR} ${OLTP_DURATION} ${TABLES} ${TABLE_SIZE} ${t} update_non_index
		done

		## 停止实例	
		aws ec2 terminate-instances --instance-ids ${INSTANCE_ID} --region $(cloud-init query region) &
	done
done

## 测试 2： 补充测试，100*3M
# 测试参数
SUT_IP_ADDR=${INSTANCE_IP_MASTER}
OLTP_DURATION=10
TABLES=100
TABLE_SIZE=3000000

for os in ${os_types} 
do
	for ins in ${instance_types} 
	do
		## 创建实例、安装软件
		echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
		eval $OPT bash launch-instances-single.sh -s mysql-jd -t ${ins} -o ${os}
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
	    bash benchmark/mysql-benchmark_sysbench_prepare.sh ${SUT_IP_ADDR} ${OLTP_DURATION} ${TABLES} ${TABLE_SIZE}
		## 数据量估算：15 个表，每个表 20000000 条记录，数据库中大小约 68,756 MB 数据
		# [Build Schema Summary]: 
		# 数据库  记录数      数据容量(MB)  索引容量(MB)
		# oltp   294912656  64290.00     4466.85

		## 使用不同的 “线程数+时间“ 的组合，执行 benchmark
		# 精简并发: 低/中/高/极端
		THREADS="4 32 128 512"
		for t in ${THREADS}
		do
		    bash benchmark/mysql-benchmark_sysbench_run-jd.sh ${SUT_IP_ADDR} ${OLTP_DURATION} ${TABLES} ${TABLE_SIZE} ${t} read_only
			bash benchmark/mysql-benchmark_sysbench_run-jd.sh ${SUT_IP_ADDR} ${OLTP_DURATION} ${TABLES} ${TABLE_SIZE} ${t} write_only
			bash benchmark/mysql-benchmark_sysbench_run-jd.sh ${SUT_IP_ADDR} ${OLTP_DURATION} ${TABLES} ${TABLE_SIZE} ${t} rw_default
			bash benchmark/mysql-benchmark_sysbench_run-jd.sh ${SUT_IP_ADDR} ${OLTP_DURATION} ${TABLES} ${TABLE_SIZE} ${t} rw_70_30
			bash benchmark/mysql-benchmark_sysbench_run-jd.sh ${SUT_IP_ADDR} ${OLTP_DURATION} ${TABLES} ${TABLE_SIZE} ${t} rw_90_10
			bash benchmark/mysql-benchmark_sysbench_run-jd.sh ${SUT_IP_ADDR} ${OLTP_DURATION} ${TABLES} ${TABLE_SIZE} ${t} point_select
			bash benchmark/mysql-benchmark_sysbench_run-jd.sh ${SUT_IP_ADDR} ${OLTP_DURATION} ${TABLES} ${TABLE_SIZE} ${t} update_index
			bash benchmark/mysql-benchmark_sysbench_run-jd.sh ${SUT_IP_ADDR} ${OLTP_DURATION} ${TABLES} ${TABLE_SIZE} ${t} update_non_index
		done

		## 停止实例	
		aws ec2 terminate-instances --instance-ids ${INSTANCE_ID} --region $(cloud-init query region) &
	done
done

