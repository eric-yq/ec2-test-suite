#!/bin/bash

SUT_NAME="SUT_XXX"

yum install -y git awscli
apt update -y && apt install -y git awscli

## 获取代码
cd /root/
git clone https://github.com/eric-yq/ec2-test-suite.git

cd ec2-test-suite/${SUT_NAME}
bash install-sut.sh ${SUT_NAME}
