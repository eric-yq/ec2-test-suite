#!/bin/bash

## 保存结果的目录
mkdir -p $0--result-summary

## 待测 EC2 规格和 OS
os_types="al2"
# instance_types="m7a.2xlarge m7g.2xlarge m7i.2xlarge m6a.2xlarge m6g.2xlarge m6i.2xlarge m5.2xlarge"
# instance_types="m7g.2xlarge"

instance_types="m6i.2xlarge m6g.2xlarge m5.2xlarge m7i.2xlarge m7a.2xlarge m6a.2xlarge "

for os in ${os_types} 
do
	for ins in ${instance_types} 
	do
		## 创建实例、安装软件
		echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
		bash launch-instances-single.sh -s mysql-sysbench -t ${ins} -o ${os}
		
		echo "$0: Sleep 180 seconds..."
		sleep 180
		
		## 执行 Benchmark 测试
		echo "$0: Star to run benchmark"
		source /tmp/temp-setting
		
		bash benchmark/mysql-benchmark_sysbench.sh ${INSTANCE_IP_MASTER} 60  9 20000000 1
		bash benchmark/mysql-benchmark_sysbench.sh ${INSTANCE_IP_MASTER} 60  9 20000000 2
		bash benchmark/mysql-benchmark_sysbench.sh ${INSTANCE_IP_MASTER} 60  9 20000000 4
		bash benchmark/mysql-benchmark_sysbench.sh ${INSTANCE_IP_MASTER} 60  9 20000000 6
		bash benchmark/mysql-benchmark_sysbench.sh ${INSTANCE_IP_MASTER} 60  9 20000000 8
		bash benchmark/mysql-benchmark_sysbench.sh ${INSTANCE_IP_MASTER} 60  9 20000000 10
		bash benchmark/mysql-benchmark_sysbench.sh ${INSTANCE_IP_MASTER} 60  9 20000000 12
		bash benchmark/mysql-benchmark_sysbench.sh ${INSTANCE_IP_MASTER} 60  9 20000000 14
		bash benchmark/mysql-benchmark_sysbench.sh ${INSTANCE_IP_MASTER} 60  9 20000000 16
		bash benchmark/mysql-benchmark_sysbench.sh ${INSTANCE_IP_MASTER} 60  9 20000000 24
		bash benchmark/mysql-benchmark_sysbench.sh ${INSTANCE_IP_MASTER} 60  9 20000000 32
		bash benchmark/mysql-benchmark_sysbench.sh ${INSTANCE_IP_MASTER} 60  9 20000000 48
		bash benchmark/mysql-benchmark_sysbench.sh ${INSTANCE_IP_MASTER} 60  9 20000000 64

# only for test
#  		bash benchmark/mysql-benchmark_sysbench.sh ${INSTANCE_IP_MASTER} 3  10 1000000 32

		## 停止实例
		aws ec2 stop-instances --instance-ids ${INSTANCE_ID} --region $(cloud-init query region)
	done
done

