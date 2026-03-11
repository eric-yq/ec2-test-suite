#!/bin/bash

# Redis Benchmark
# 待测 EC2 规格和 OS
os_types="al2023"
instance_types="$1"

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
		eval $OPT bash launch-instances-single.sh -s blank -t ${ins} -o ${os}
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
		source /tmp/temp-setting
		echo "[$(date +%Y%m%d.%H%M%S)] Sleep 60s to simulate benchmark......" && sleep 60
		touch benchmark-result-files/placeholder.txt

		# 将结果目录打包上传到 S3
		TIMESTAMP=$(date +%Y%m%d%H%M%S)
		TARGET_DIR="${SUT_NAME}_${INSTANCE_TYPE}_${TIMESTAMP}"
		cp -r benchmark-result-files ${TARGET_DIR}	
		cp screenlog.0 ${TARGET_DIR}/
		tar czf ${TARGET_DIR}.tar.gz ${TARGET_DIR}
		aws s3 cp ${TARGET_DIR}.tar.gz s3://ec2-core-benchmark-ericyq/result_${SUT_NAME}/
		
		# 停止 dool 监控
		sleep 10
		# killall ssh dool
		
		## 终止实例
		aws ec2 terminate-instances --instance-ids ${INSTANCE_ID} $(ec2-metadata --quiet -i) \
		    --region $(ec2-metadata --quiet --region) &
		
	done
done

echo "$0: Blank benchmark completed."
