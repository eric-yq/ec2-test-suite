#!/bin/bash

SUT_NAME="SUT_XXX"
INSTANCE_IP_WEB1="INSTANCE_IP_WEB1_XXX"
INSTANCE_IP_WEB2="INSTANCE_IP_WEB2_XXX"

yum install -yq git awscli

## 获取代码
cd /root/
git clone https://github.com/eric-yq/ec2-test-suite.git

cd ec2-test-suite/${SUT_NAME}
bash install-sut.sh ${SUT_NAME} ${INSTANCE_IP_WEB1} ${INSTANCE_IP_WEB2}
 