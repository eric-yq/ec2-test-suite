#!/bin/bash

## 使用方法： bash nginx-benchmark.sh <IP地址>

SUT_IP_ADDR=${1}
TEST_TIME=${2}

source /tmp/temp-setting
RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}

# 执行OS优化
bash $(dirname $0)/os-optimization.sh

# 命令
THREADS=${INSTANCE_VCPU_NUM}
CONNECTIONS="10 20 30 40 60 80 100 150 200 300"
# RESOURCE_FILE="test.html"
RESOURCE_FILE="1kb.bin"
DURATION='3m'
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_LOADBALANCE}.txt"

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
    

