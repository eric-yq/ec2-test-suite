#!/bin/bash

set -e

## 待测 EC2 规格和 OS
os_types="al2023"
instance_types="$1" ## 待测 EC2 规格，多个规格用空格分隔
data_size=$2 ## 数据量大小，单位为 GB

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
		eval $OPT bash launch-instances-single.sh -s mysql-instancestore -t ${ins} -o ${os}
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
		bash benchmark/mysql-benchmark_v2_prepare.sh ${INSTANCE_IP_MASTER} ${data_size} ${ins} 

		## 使用不同的vuser执行benchmark
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  1 ${data_size} ${ins} 
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  2 ${data_size} ${ins} 
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  4 ${data_size} ${ins} 
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  6 ${data_size} ${ins} 
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  8 ${data_size} ${ins} 
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 30 10 ${data_size} ${ins} 
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 30 12 ${data_size} ${ins} 
		bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 30 16 ${data_size} ${ins}

		# 停止 dool 监控
		sleep 10
		# killall ssh dool

		# 将结果目录打包上传到 S3
		TIMESTAMP=$(date +%Y%m%d%H%M%S)
		TARGET_DIR="${SUT_NAME}_${INSTANCE_TYPE}_${TIMESTAMP}"
		cp -r benchmark-result-files ${TARGET_DIR}	
		cp screenlog.0 ${TARGET_DIR}/
		wget http://${INSTANCE_IP_MASTER}:9527/dool-sut.txt -O ${TARGET_DIR}/dool-sut.txt
		tar czf ${TARGET_DIR}.tar.gz ${TARGET_DIR}
		aws s3 cp ${TARGET_DIR}.tar.gz s3://${BENCHMARK_RESULT_BUCKET}/result_${SUT_NAME}/
		
		## 终止实例
		aws ec2 terminate-instances --region $(ec2-metadata --quiet --region) --instance-ids ${INSTANCE_ID} && \
		echo "[$(date +%Y%m%d.%H%M%S)] Terminated instance ${INSTANCE_ID} for OS_TYPE=${os}, INSTANCE_TYPE=${ins}."
	done
done

echo "$(date +%Y%m%d.%H%M%S)] ${SUT_NAME} benchmark completed. Loadgen instance will be terminicated after 30s." && sleep 30
aws ec2 terminate-instances --region $(ec2-metadata --quiet --region) --instance-ids $(ec2-metadata --quiet -i) 
