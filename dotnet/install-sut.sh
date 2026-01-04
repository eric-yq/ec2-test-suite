#!/bin/bash

set -e


SUT_NAME=${1}
echo "$0: Install SUT_NAME: ${SUT_NAME}"

## 获取OS 、CPU 架构信息。
OS_NAME=$(egrep ^NAME /etc/os-release | awk -F "\"" '{print $2}')
OS_VERSION=$(egrep ^VERSION_ID /etc/os-release | awk -F "\"" '{print $2}') 

if  [[ "$OS_NAME" == "Amazon Linux" ]] && [[ "$OS_VERSION" == "2023" ]]; then
	echo "$0: OS is $OS_NAME $OS_VERSION . "
else
	echo "$0: $OS_NAME not supported"
	exit 1
fi
	
install_public_tools(){
    yum update -y 
	yum install -yq python3-pip git yq
	pip3 install dool
}

## 安装
install_sut(){
    yum install -yq aspnetcore-runtime-8.0 dotnet-runtime-8.0 dotnet-sdk-8.0
    dotnet tool install -g Microsoft.Crank.Controller --version "0.2.0-*" 
    dotnet tool install -g Microsoft.Crank.Agent --version "0.2.0-*"
    cat << EOF >> ~/.bash_profile
# Add .NET Core SDK tools
export PATH="$PATH:/root/.dotnet/tools"
EOF
    source ~/.bash_profile
}

## 启动
start_sut(){
    cd /root/
    nohup crank-agent &
}

## 主要流程
install_public_tools
os_configure
install_sut
start_sut
