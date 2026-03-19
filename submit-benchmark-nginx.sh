#!/bin/bash

# 待测 EC2 规格和 OS
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
		eval $OPT bash launch-instances-nginx.sh -s nginx -t ${ins} -o ${os}
		# 检查实例启动状态：如果失败则跳过后续测试。
		launch_status=$?
		if [ $launch_status -ne 0 ]; then
			echo "$0: [$(date +%Y%m%d.%H%M%S)] Instance launch failed for OS_TYPE=${os}, INSTANCE_TYPE=${ins}. Continuing with next configuration..."
			rm -rf nginx-webserver/tf_cfg_nginx-webserver/
			rm -rf nginx-loadbalancer/tf_cfg_nginx-loadbalance/
			continue
		fi

		####################################
		# 实例类型、IP 地址和实例 ID 记录到文件
		source /tmp/temp-setting
		echo "${ins} ${INSTANCE_IP_LOADBALANCE} ${INSTANCE_ID}" >> /tmp/servers.txt
		echo "[$(date +%Y%m%d.%H%M%S)] Sleep 30 seconds ..." && sleep 30
		# 执行 ping 测试
		echo "[$(date +%Y%m%d.%H%M%S)] Ping latency test, result shows the avg. latency only. Extra option : ${OPT}"
		ping_result=$(ping -q -c 60 ${INSTANCE_IP_LOADBALANCE} | tail -n 1 | awk -F '/' '{print $5 " ms"}') 
		echo "[$(date +%Y%m%d.%H%M%S)]   ${ins}, ${INSTANCE_IP_LOADBALANCE} : ${ping_result}"
		echo "[$(date +%Y%m%d.%H%M%S)] Sleep 120 seconds before benchmark test..." && sleep 120
	    ####################################
		
		## 执行 Benchmark 测试
		echo "[$(date +%Y%m%d.%H%M%S)] Star to run benchmark"
		source /tmp/temp-setting
		bash benchmark/nginx-benchmark.sh ${INSTANCE_IP_LOADBALANCE}

		# 停止 dool 监控
		sleep 10
		# killall ssh dool

		# 将结果目录打包上传到 S3
		TIMESTAMP=$(date +%Y%m%d%H%M%S)
		TARGET_DIR="${SUT_NAME}_${INSTANCE_TYPE}_${TIMESTAMP}"
		cp -r benchmark-result-files ${TARGET_DIR}	
		cp screenlog.0 ${TARGET_DIR}/
		tar czf ${TARGET_DIR}.tar.gz ${TARGET_DIR}
		wget http://${INSTANCE_IP_LOADBALANCE}:9527/dool-sut.txt -O ${TARGET_DIR}/dool-sut.txt
		aws s3 cp ${TARGET_DIR}.tar.gz s3://${BENCHMARK_RESULT_BUCKET}/result_${SUT_NAME}/

		## 终止实例
		aws ec2 terminate-instances --region $(ec2-metadata --quiet --region) \
		    --instance-ids ${INSTANCE_ID_WEB1} ${INSTANCE_ID_WEB2} ${INSTANCE_ID_LOADBALANCE} && \
		echo "[$(date +%Y%m%d.%H%M%S)] Terminated instance ${INSTANCE_ID_WEB1}, ${INSTANCE_ID_WEB2}, ${INSTANCE_ID_LOADBALANCE} for OS_TYPE=${os}, INSTANCE_TYPE=${ins}."
	done
done

echo "$(date +%Y%m%d.%H%M%S)] ${SUT_NAME} benchmark completed. Loadgen instance will be terminicated after 30s." && sleep 30
aws ec2 terminate-instances --region $(ec2-metadata --quiet --region) --instance-ids $(ec2-metadata --quiet -i) 

