#!/bin/bash

# 待测 EC2 规格和 OS
os_types="al2023"
instance_types="$1"

## CPG 选项
if [ "$USE_CPG" = "1" ] ; then
  OPT="USE_CPG=1"
else
  OPT="USE_CPG=0"
fi

# 清理临时文件
rm -rf /tmp/servers.txt /tmp/ping_latency_log.txt

for os in ${os_types} 
do
	for ins in ${instance_types} 
	do
		## 创建实例、安装软件
		echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
		eval $OPT bash launch-instances-single.sh -s milvus -t ${ins} -o ${os}
		# 检查实例启动状态：如果失败则跳过后续测试。
		launch_status=$?
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
		bash benchmark/milvus-benchmark.sh ${INSTANCE_IP_MASTER}
		
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

