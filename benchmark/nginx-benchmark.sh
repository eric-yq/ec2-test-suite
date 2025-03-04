#!/bin/bash

## 使用方法： bash nginx-benchmark.sh <IP地址>

SUT_IP_ADDR=${1}
TEST_TIME=${2}

source /tmp/temp-setting
RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}


sysctl -w net.core.somaxconn=65535
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
sysctl -w net.ipv4.tcp_max_syn_backlog=65535
sysctl -w net.ipv4.tcp_tw_reuse=1
sysctl -w net.ipv4.tcp_fastopen=3
sysctl -w net.ipv4.tcp_congestion_control=bbr
sysctl -w net.ipv4.ip_local_port_range="1024 65535"
sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216"
sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216"
sysctl -w fs.file-max=1000000
ulimit -n 1000000
echo never > /sys/kernel/mm/transparent_hugepage/enabled


# 命令
THREADS=${INSTANCE_VCPU_NUM}
# CONNECTIONS="8 16 32"
CONNECTIONS="8 16 32 48 64 96 128 192 256"
# CONNECTIONS="10 20 30 40 60 80 100 150 200 300"
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
    

