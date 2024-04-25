#!/bin/bash

## 使用方法： bash nginx-benchmark.sh <IP地址>

SUT_IP_ADDR=${1}
TEST_TIME=${2}

source /tmp/temp-setting
RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}


# 命令
THREADS=${INSTANCE_VCPU_NUM}
# CONNECTIONS="8 16 32"
CONNECTIONS="8 16 32 48 64 96 128 192 256"
RESOURCE_FILE="test.html"
DURATION='3m'
RESULT_FILE="${RESULT_PATH}/${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_LOADBALANCE}.txt"

for i in $CONNECTIONS
do
    cat << EOF > ~/wrk-4.2.0/report.lua 
done = function(summary, latency, requests)
   io.write("------------------------------\n")
   rps = summary.requests / (summary.duration/1000/1000)
   io.write(string.format("%s, %s, RPS=%g , Latency(P50)=%d us, Latency(P90)=%d us, Latency(P99)=%d us, Latency(P99.99)=%d us\n", "$INSTANCE_TYPE" , "$i" , rps, latency:percentile(50),latency:percentile(90),latency:percentile(99),latency:percentile(99.99)))
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
    

