#!/bin/bash

## 运行脚本的实例所在的 CPG 名称
CPG_NAME=$(aws ec2 describe-instances \
  --instance-ids $(ec2-metadata --quiet -i) \
  --query 'Reservations[0].Instances[0].Placement.GroupName' \
  --output text)

if [ -z "$CPG_NAME" ] || [ "$CPG_NAME" == "None" ]; then
  echo "当前实例不在任何 Cluster Placement Group 中，无法进行 CPG 检查。"
  exit 1
fi

SUT_TYPES=("r8a.2xlarge" "r8g.2xlarge" "r8i.2xlarge" "r7a.2xlarge" "r7g.2xlarge" "r7i.2xlarge" "r6a.2xlarge" "r6g.2xlarge" "r6i.2xlarge")

# 自动获取 ARM64 AMI（用于 Graviton）
ARM_AMI=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023*-arm64" \
          "Name=state,Values=available" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text)

# 自动获取 x86_64 AMI
X86_AMI=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023*-x86_64" \
          "Name=state,Values=available" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text)

echo "ARM64 AMI: $ARM_AMI"
echo "x86_64 AMI: $X86_AMI"

for instance_type in "${SUT_TYPES[@]}"; do
  # 判断是 Graviton 还是 x86
  if [[ $instance_type == *"g."* ]]; then
    AMI=$ARM_AMI
  else
    AMI=$X86_AMI
  fi
  
  echo "Testing $instance_type with AMI $AMI..."
  
  instance_id=$(aws ec2 run-instances \
    --instance-type "$instance_type" \
    --placement "GroupName=$CPG_NAME" \
    --image-id "$AMI" \
    --query 'Instances[0].InstanceId' \
    --output text 2>&1)
  
  if [[ $? -eq 0 ]]; then
    echo "✓ $instance_type can join CPG"
    # aws ec2 terminate-instances --instance-ids "$instance_id" > /dev/null
  else
    echo "✗ $instance_type cannot join CPG: $instance_id"
  fi
  
  sleep 2
done