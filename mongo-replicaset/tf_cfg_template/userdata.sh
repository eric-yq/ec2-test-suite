#!/bin/bash

SUT_NAME="SUT_XXX"

yum install -y git awscli
dnf install -y git awscli
apt update -y && apt install -y git awscli


yum install -y git awscli git
apt update -y && apt install -y git awscli


## 获取代码
cd /root/
git clone https://github.com/eric-yq/aws-ec2-benchmark-suite.git

cd aws-ec2-benchmark-suite/${SUT_NAME}
bash install-sut.sh ${SUT_NAME}
