#!/bin/bash

## 现在 c6i.12x 跑通，再用 c7g.12x

sudo su - root

# 为防止超时，启动过一个新session，
screen -R ttt -L
# 如果要退出session的话，使用Ctrl+A+D
# 重新进入Session，使用 screen -r ttt.


# 开发工具
sudo apt update 
sudo apt install -y git build-essential libffi-dev gnupg flex bison gperf zip curl zlib1g-dev libncurses5 x11proto-core-dev libx11-dev zlib1g-dev ccache libgl1-mesa-dev libxml2-utils xsltproc unzip

## 下面配置用你的github账号
git config --global user.name "xxx"
git config --global user.email "xxx"

# 安装repo
mkdir ~/bin  
echo "PATH=~/bin:$PATH" >> ~/.bash_profile
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo  
chmod a+x ~/bin/repo  

# 安装 jdk
sudo apt install -y openjdk-17-jdk-headless
echo "export JAVA_HOME=$(ls -d /usr/lib/jvm/java-17-openjdk-*)" >> ~/.bash_profile
echo "export PATH=$JAVA_HOME/bin:$PATH" >> ~/.bash_profile

source ~/.bash_profile

# 初始化代码仓库
mkdir android-source  
cd android-source  
repo init -u https://android.googlesource.com/platform/manifest -b android-14.0.0_r20 ## --partial-clone

# 同步源码
repo sync -j4 -c --no-tags
# 如果卡住或者看上去不太正常的话，用 Ctrl+Z 停止任务，再重新执行。 

# 编译构建
## 测试1：
source build/envsetup.sh
make clobber
lunch aosp_x86_64-eng
make -j32
#### build completed successfully (54:46 (mm:ss)) #### c6i.12xlarge

## have errors on c7g.12x
# /root/android-source/build/blueprint/microfactory/microfactory.bash: line 63: /root/android-source/prebuilts/go/linux-x86//bin/go: cannot execute binary file: Exec format error



## 测试2：
make clobber
lunch aosp_arm64-eng
make -j32
#### build completed successfully (57:54 (mm:ss)) #### c6i.12xlarge


## Ubuntu 20.04 AMI ID查询方法，us-east-2
# amd64
aws ssm get-parameter --name /aws/service/canonical/ubuntu/server/20.04/stable/current/amd64/hvm/ebs-gp2/ami-id --region us-east-2 --query Parameter.Value --output text
ami-08529db39844c00c2
# arm64
aws ssm get-parameter --name /aws/service/canonical/ubuntu/server/20.04/stable/current/arm64/hvm/ebs-gp2/ami-id --region us-east-2 --query Parameter.Value --output text
ami-0c7094645d3cbad2e

## Reference :
## https://www.jianshu.com/p/197096d3206d
## https://www.cnblogs.com/fly263/p/16982647.html
## https://source.android.com/docs/setup/download?hl=zh-cn

