#!/bin/bash

SUT_NAME="SUT_XXX"
sleep 10
echo "[Info] Sleep 10s to start run user data scripts..."

yum install -yq git

## 获取代码
cd /root/
git clone https://github.com/eric-yq/ec2-test-suite.git

cd ec2-test-suite/${SUT_NAME}
bash install-sut.sh ${SUT_NAME}
