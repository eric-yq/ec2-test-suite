#!/bin/bash

## 使用方法： bash nginx-benchmark.sh <IP地址>

SUT_IP_ADDR=${1}
TEST_TIME=${2}

source /tmp/temp-setting
RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}

# 命令
THREADS=${INSTANCE_VCPU_NUM}
CONNECTIONS="10 20 30 40 60 80 100 150 200 300"
# RESOURCE_FILE="test.html"
RESOURCE_FILE="1kb.bin"
DURATION='3m'
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_LOADBALANCE}.txt"

## 启动一个后台进程，执行dool命令，获取系统性能信息
DOOL_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}_dool-sut.txt"
ssh -o StrictHostKeyChecking=no -i ~/ericyq-global.pem ec2-user@${SUT_IP_ADDR} \
  "dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60" \
  1> ${DOOL_FILE} 2>&1 &
DOOL_FILE_LOADGEN="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_MASTER}_dool-loadgen.txt"
nohup dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60 \
  1> ${DOOL_FILE_LOADGEN} 2>&1 &

for i in $CONNECTIONS
do
    cat << EOF > ~/wrk-4.2.0/report.lua 
done = function(summary, latency, requests)
   io.write("------------------------------\n")
   rps = summary.requests / (summary.duration/1000/1000)
   io.write(string.format("%s, %s, RPS, %g, %d, %d, %d, %d\n", "$INSTANCE_TYPE" , "$i" , rps, latency:percentile(50),latency:percentile(90),latency:percentile(99),latency:percentile(99.99)))
end
EOF

	~/wrk-4.2.0/wrk --threads $THREADS --connections $i --duration $DURATION \
		--script ~/wrk-4.2.0/report.lua https://$SUT_IP_ADDR/$RESOURCE_FILE >> $RESULT_FILE
		
# 	~/wrk-4.2.0/wrk --threads ${THREADS} --connections ${CONNECTIONS} --duration ${DURATION} \
# 		--script ~/wrk-4.2.0/report.lua -H 'Connection: close' \
# 		https://${SUT_IP_ADDR}/${RESOURCE_FILE} | grep BENCH >> ${RESULT_FILE}
		
#    ~/wrk2/wrk --threads ${THREADS} --connections ${CONNECTIONS} --duration ${DURATION} \
#       --script ~/wrk2/report.lua --rate ${RATE} -H 'Connection: close' \
#       https://${SUT_IP_ADDR}/${RESOURCE_FILE} | grep BENCH >> ${RESULT_FILE}

	sleep 10
done
    
# 停止 dool 监控
sleep 10 && killall ssh dool