#!/bin/bash

# cd /root/ec2-test-suite

### run benchmark 
cat << EOF > /tmp/temp-setting
export SUT_NAME="mongo"
export INSTANCE_IP_MASTER="172.31.18.70"
export INSTANCE_TYPE="i8g.2xlarge"
export OS_TYPE="al2023"
EOF
source /tmp/temp-setting
bash benchmark/mongo-benchmark_v2.sh ${INSTANCE_IP_MASTER}

### run benchmark 
cat << EOF > /tmp/temp-setting
export SUT_NAME="mongo"
export INSTANCE_IP_MASTER="172.31.20.225"
export INSTANCE_TYPE="i4g.2xlarge"
export OS_TYPE="al2023"
EOF
source /tmp/temp-setting
bash benchmark/mongo-benchmark_v2.sh ${INSTANCE_IP_MASTER}


