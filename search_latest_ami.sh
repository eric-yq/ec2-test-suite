#!/bin/bash

## 为实例规格查找最新的AMI，

# set -e

source /tmp/temp-setting

## 查询实例类型的 CPU 架构 arm64, x86_64，根据CPU 架构查询最新的 Amazon Linux 2 的 AMI
CPU_ARCH=$(aws ec2 describe-instance-types \
  --region ${REGION_NAME}  \
  --instance-types ${INSTANCE_TYPE} \
  --query InstanceTypes[0].ProcessorInfo.SupportedArchitectures[0] \
  --output text)
# echo "$0: REGION_NAME=${REGION_NAME}, INSTANCE_TYPE=${INSTANCE_TYPE}, CPU_ARCH=${CPU_ARCH}"

INSTANCE_VCPU_NUM=$(aws ec2 describe-instance-types \
  --region ${REGION_NAME}  \
  --instance-types ${INSTANCE_TYPE} \
  --query InstanceTypes[0].VCpuInfo.DefaultVCpus \
  --output text)
  
INSTANCE_MEM_SIZE=$(aws ec2 describe-instance-types \
  --region ${REGION_NAME}  \
  --instance-types ${INSTANCE_TYPE} \
  --query InstanceTypes[0].MemoryInfo.SizeInMiB \
  --output text)

AMI_OWNERS="--owners amazon"

### Amazon Linux 2: al2 
if   [[ "${OS_TYPE}" == "al2" ]]; then

    AMI_NAME="amzn2-ami-kernel-5.10-hvm-*-${CPU_ARCH}-gp2"
 
### Amazon Linux 2023: al2023
elif [[ "${OS_TYPE}" == "al2023" ]]; then
	
    AMI_NAME="al2023-ami-2023.*-kernel-6.1-${CPU_ARCH}"
    
### Ubuntu: ubuntu2004, ubuntu2204
elif [[ "${CPU_ARCH}" == "arm64" ]] && [[ "${OS_TYPE}" == "ubuntu2004" ]]; then

    AMI_NAME="ubuntu/images/hvm-ssd/ubuntu-focal-20.04-arm64-server-*"

elif [[ "${CPU_ARCH}" == "arm64" ]] && [[ "${OS_TYPE}" == "ubuntu2204" ]]; then

    AMI_NAME="ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"
    
elif [[ "${CPU_ARCH}" == "x86_64" ]] && [[ "${OS_TYPE}" == "ubuntu2004" ]]; then

    AMI_NAME="ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
    
elif [[ "${CPU_ARCH}" == "x86_64" ]] && [[ "${OS_TYPE}" == "ubuntu2204" ]]; then
    
    AMI_NAME="ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"

### Debian: debian10, debian11
elif [[ "${CPU_ARCH}" == "arm64" ]] && [[ "${OS_TYPE}" == "debian10" ]]; then

    AMI_NAME="debian-10-arm64-*"
    
elif [[ "${CPU_ARCH}" == "x86_64" ]] && [[ "${OS_TYPE}" == "debian10" ]]; then
    
    AMI_NAME="debian-10-amd64-*"
    
elif [[ "${CPU_ARCH}" == "arm64" ]] && [[ "${OS_TYPE}" == "debian11" ]]; then

    AMI_NAME="debian-11-arm64-*"
    
elif [[ "${CPU_ARCH}" == "x86_64" ]] && [[ "${OS_TYPE}" == "debian11" ]]; then
    
    AMI_NAME="debian-11-amd64-*"

### CentOS: centos7, centos8, centos9
elif [[ "${CPU_ARCH}" == "arm64" ]] && [[ "${OS_TYPE}" == "centos7" ]]; then

    AMI_NAME="CentOS Linux 7 aarch64 *"
    AMI_OWNERS=""

elif [[ "${CPU_ARCH}" == "arm64" ]] && [[ "${OS_TYPE}" == "centos8" ]]; then

    AMI_NAME="CentOS Stream 8 aarch64"
    AMI_OWNERS=""
    
elif [[ "${CPU_ARCH}" == "arm64" ]] && [[ "${OS_TYPE}" == "centos9" ]]; then

    AMI_NAME="CentOS Stream 9 aarch64 *" 
    AMI_OWNERS=""
    
elif [[ "${CPU_ARCH}" == "x86_64" ]] && [[ "${OS_TYPE}" == "centos7" ]]; then

    AMI_NAME="CentOS Linux 7 x86_64 *"
    AMI_OWNERS=""

elif [[ "${CPU_ARCH}" == "x86_64" ]] && [[ "${OS_TYPE}" == "centos8" ]]; then

    AMI_NAME="CentOS Stream 8 x86_64"
    AMI_OWNERS=""
    
elif [[ "${CPU_ARCH}" == "x86_64" ]] && [[ "${OS_TYPE}" == "centos9" ]]; then

    AMI_NAME="CentOS Stream 9 x86_64 *" 
    AMI_OWNERS=""
    
### Others 
else
    echo "$OS_TYPE not supported"
    exit 
fi

# echo "$0: AMI_NAME=${AMI_NAME}"

AMI_ID=$(aws ec2 describe-images \
  --region ${REGION_NAME}  ${AMI_OWNERS} \
  --filters "Name=name,Values=${AMI_NAME}" \
  --query 'reverse(sort_by(Images,&CreationDate))[:1].{id:ImageId}' \
  --output text)

AMI_ID_NAME=$(aws ec2 describe-images \
  --region ${REGION_NAME}  ${AMI_OWNERS} \
  --filters "Name=name,Values=${AMI_NAME}" \
  --query 'reverse(sort_by(Images,&CreationDate))[:1].{name:Name}' \
  --output text)
  
# echo "$0: AMI_ID=${AMI_ID}, AMI_ID_NAME=\"${AMI_ID_NAME}\" ."

## 保存变量
echo "export CPU_ARCH=${CPU_ARCH}" >> /tmp/temp-setting
echo "export INSTANCE_VCPU_NUM=${INSTANCE_VCPU_NUM}"  >> /tmp/temp-setting
echo "export INSTANCE_MEM_SIZE=${INSTANCE_MEM_SIZE}"  >> /tmp/temp-setting
echo "export AMI_ID=${AMI_ID}" >> /tmp/temp-setting
echo "export AMI_ID_NAME=\"${AMI_ID_NAME}\"" >> /tmp/temp-setting
