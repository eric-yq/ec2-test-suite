#!/bin/bash

set -e

## 待测 EC2 规格和 OS
os_types="al2023"
# instance_types="m9g.2xlarge"
instance_types="$1"

# loadgen上执行一遍 OS/网络优化脚本
bash benchmark/os-optimization.sh

## MySQL
for os in ${os_types} 
do
    for ins in ${instance_types} 
    do
        ## 创建实例、安装软件
        echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
        bash launch-instances-single.sh -s mysql-ebs -t ${ins} -o ${os}
        launch_status=$?

        # 检查启动状态
        if [ $launch_status -ne 0 ]; then
            echo "\$0: [$(date +%Y%m%d.%H%M%S)] Instance launch failed for OS_TYPE=${os}, INSTANCE_TYPE=${ins}. Continuing with next configuration..."
            rm -rf mysql-ebs/tf_cfg_mysql-ebs/
            continue
        fi

        echo "$0: [$(date +%Y%m%d.%H%M%S)] Sleep 600 seconds ..."
        sleep 600

        ## 执行 Benchmark 测试
        echo "$0: Star to run benchmark"
        source /tmp/temp-setting

        ## 准备数据: r8i.2xlage 使用 64G; m8i.2xlarge 使用 24G 
        bash benchmark/mysql-benchmark_v2_prepare.sh ${INSTANCE_IP_MASTER} 24 ${ins} 

        ## 使用不同的vuser执行benchmark
        bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  1 24 ${ins} 
        bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  2 24 ${ins} 
        bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  4 24 ${ins} 
        bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  6 24 ${ins} 
        bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 60  8 24 ${ins} 
        bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 30 10 24 ${ins}
        bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 30 12 24 ${ins} 
        bash benchmark/mysql-benchmark_v2_run.sh ${INSTANCE_IP_MASTER} 30 16 24 ${ins} 

        ## 停止实例
        aws ec2 terminate-instances --instance-ids ${INSTANCE_ID} --region $(cloud-init query region) &
    done
done

sleep 60
## MongoDB
for os in ${os_types} 
do
    for ins in ${instance_types} 
    do
        ## 创建实例、安装软件
        echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
        bash launch-instances-single.sh -s mongo -t ${ins} -o ${os}
        # 检查实例启动状态：如果失败则跳过后续测试。
        launch_status=$?
        if [ $launch_status -ne 0 ]; then
            echo "\$0: [$(date +%Y%m%d.%H%M%S)] Instance launch failed for OS_TYPE=${os}, INSTANCE_TYPE=${ins}. Continuing with next configuration..."
            rm -rf mongo/tf_cfg_mongo/
            continue
        fi

        echo "$0: [$(date +%Y%m%d.%H%M%S)] Sleep 600 seconds..."
        sleep 600

        ## 执行 Benchmark 测试
        echo "$0: Star to run benchmark"
        source /tmp/temp-setting
        bash benchmark/mongo-benchmark_v2.sh ${INSTANCE_IP_MASTER}

        ## 停止实例
        aws ec2 terminate-instances --instance-ids ${INSTANCE_ID} --region $(cloud-init query region) &
    done
done

sleep 60
## Redis
for os in ${os_types} 
do
    for ins in ${instance_types} 
    do
        ## 创建实例、安装软件
        echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
        bash launch-instances-single.sh -s redis -t ${ins} -o ${os}
        # 检查实例启动状态：如果失败则跳过后续测试。
        launch_status=$?
        if [ $launch_status -ne 0 ]; then
            echo "\$0: [$(date +%Y%m%d.%H%M%S)] Instance launch failed for OS_TYPE=${os}, INSTANCE_TYPE=${ins}. Continuing with next configuration..."
            rm -rf redis/tf_cfg_redis/
            continue
        fi

        echo "$0: [$(date +%Y%m%d.%H%M%S)] Sleep 600 seconds..."
        sleep 600

        ## 执行 Benchmark 测试
        echo "$0: Star to run benchmark"
        source /tmp/temp-setting
        bash benchmark/redis-benchmark_v1.sh ${INSTANCE_IP_MASTER} 6379 180
        # bash benchmark/redis-benchmark_v1.sh ${INSTANCE_IP_MASTER} 8003 180
        bash benchmark/redis-benchmark_v1.sh ${INSTANCE_IP_MASTER} 8005 180
        # bash benchmark/redis-benchmark_v1.sh ${INSTANCE_IP_MASTER} 8007 180

        ## 停止实例
        aws ec2 terminate-instances --instance-ids ${INSTANCE_ID} --region $(cloud-init query region) &
    done
done

sleep 60
## Valkey
for os in ${os_types} 
do
    for ins in ${instance_types} 
    do
        ## 创建实例、安装软件
        echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
        bash launch-instances-single.sh -s valkey -t ${ins} -o ${os}
        # 检查实例启动状态：如果失败则跳过后续测试。
        launch_status=$?
        if [ $launch_status -ne 0 ]; then
            echo "\$0: [$(date +%Y%m%d.%H%M%S)] Instance launch failed for OS_TYPE=${os}, INSTANCE_TYPE=${ins}. Continuing with next configuration..."
            rm -rf valkey/tf_cfg_valkey/
            continue
        fi

        echo "$0: [$(date +%Y%m%d.%H%M%S)] Sleep 600 seconds ..."
        sleep 600

        ## 执行 Benchmark 测试，使用 redis-benchmark_v1.sh 脚本
        echo "$0: Star to run benchmark"
        source /tmp/temp-setting
        # bash benchmark/redis-benchmark_v1.sh ${INSTANCE_IP_MASTER} 6379 180
        # bash benchmark/redis-benchmark_v1.sh ${INSTANCE_IP_MASTER} 8003 180
        # bash benchmark/redis-benchmark_v1.sh ${INSTANCE_IP_MASTER} 8005 180
        bash benchmark/redis-benchmark_v1.sh ${INSTANCE_IP_MASTER} 8007 180

        ## 停止实例
        aws ec2 terminate-instances --instance-ids ${INSTANCE_ID} --region $(cloud-init query region) &
    done
done

sleep 60
## Nginx
for os in ${os_types} 
do
    for ins in ${instance_types} 
        do
        ## 创建实例、安装软件
        echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
        bash launch-instances-nginx.sh -s nginx -t ${ins} -o ${os}
        # 检查实例启动状态：如果失败则跳过后续测试。
        launch_status=$?
        if [ $launch_status -ne 0 ]; then
            echo "$0: [$(date +%Y%m%d.%H%M%S)] Instance launch failed for OS_TYPE=${os}, INSTANCE_TYPE=${ins}. Continuing with next configuration..."
            rm -rf nginx-webserver/tf_cfg_nginx-webserver/
            rm -rf nginx-loadbalancer/tf_cfg_nginx-loadbalance/
            continue
        fi

        echo "$0: [$(date +%Y%m%d.%H%M%S)] Sleep 600 seconds..."
        sleep 600

        ## 执行 Benchmark 测试
        echo "$0: Star to run benchmark"
        source /tmp/temp-setting
        bash benchmark/nginx-benchmark.sh ${INSTANCE_IP_LOADBALANCE}

        ## 停止实例
        aws ec2 terminate-instances --region $(cloud-init query region) \
        --instance-ids ${INSTANCE_ID_LOADBALANCE} ${INSTANCE_ID_WEB1} ${INSTANCE_ID_WEB2} &
    done
done

sleep 60
## Milvus
for os in ${os_types} 
do
	for ins in ${instance_types} 
	do
		## 创建实例、安装软件
		echo "$0: OS_TYPE=${os}, INSTANCE_TYPE=${ins}"
		bash launch-instances-single.sh -s milvus -t ${ins} -o ${os}
		# 检查实例启动状态：如果失败则跳过后续测试。
		launch_status=$?
		if [ $launch_status -ne 0 ]; then
			echo "\$0: [$(date +%Y%m%d.%H%M%S)] Instance launch failed for OS_TYPE=${os}, INSTANCE_TYPE=${ins}. Continuing with next configuration..."
			rm -rf milvus/tf_cfg_milvus/
            continue
		fi
		
		echo "$0: [$(date +%Y%m%d.%H%M%S)] Sleep 600 seconds..."
		sleep 600

		## 执行 Benchmark 测试
		echo "$0: Star to run benchmark"
		source /tmp/temp-setting
		bash benchmark/milvus-benchmark.sh ${INSTANCE_IP_MASTER}
		
		## 停止实例
		aws ec2 terminate-instances --instance-ids ${INSTANCE_ID} --region $(cloud-init query region) &
	done
done