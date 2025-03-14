#!/bin/bash

SUT_NAME="SUT_XXX"
echo "[Info] Sleep 30s to start run user data scripts..."
sleep 30

yum install -yq git

## 获取代码
cd /root/
git clone https://github.com/eric-yq/ec2-test-suite.git

cd ec2-test-suite/${SUT_NAME}
bash install-sut.sh ${SUT_NAME}
