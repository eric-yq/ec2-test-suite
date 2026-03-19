#!/bin/bash

## 样例
## bash launch-instances-nginx.sh -s nginx -t c8g.2xlarge -o al2023

## 命令行参数
while getopts 's:t:o:' OPT; do
    case $OPT in
        s) SUT_NAME="$OPTARG";;
        t) INSTANCE_TYPE="$OPTARG";;
        o) OS_TYPE="$OPTARG";;  ## al2, al2023, ubuntu2004, ubuntu2204
    esac
done

if [[ -z ${SUT_NAME} ]]
then
    echo "$0: You MUST specify SUT name with option -s ."
    echo "$0: It can be: redis, mysql, mongo, etc ."
    exit
fi

if [[ -z ${INSTANCE_TYPE} ]]
then
    echo "$0: You MUST specify Instance Type with option -t ."
    exit
fi

if [[ -z ${OS_TYPE} ]]
then
    echo "$0: You do not specify OS Type with option -o, So we will use OS(Amazon Linux 2023) by default. "
    OS_TYPE=al2023
fi

REGION_NAME=$(ec2-metadata --quiet --region)
echo "" > /tmp/temp-setting
echo "export REGION_NAME=${REGION_NAME}" >> /tmp/temp-setting
echo "export INSTANCE_TYPE=${INSTANCE_TYPE}" >> /tmp/temp-setting
echo "export OS_TYPE=${OS_TYPE}" >> /tmp/temp-setting
echo "export SUT_NAME=${SUT_NAME}" >> /tmp/temp-setting


## 根据实例类型、OS 类型查找最新的 AMI。
bash search_latest_ami.sh

source /tmp/temp-setting

###################################################################################################
# 1. 创建 2 台 nginx-webserver
## 创建对应的 terraform 配置文件目录
echo "$0: Launch 2 nginx webserver..."
SUT_NAME="nginx-webserver"
cd ${SUT_NAME}
cp -rf tf_cfg_template tf_cfg_${SUT_NAME}
cd tf_cfg_${SUT_NAME}

# 获取 Subnet ID，Security Group ID和 placement group name
read SUBNET_ID_XXX SG_ID_XXX PG_NAME_XXX KEY_NAME_XXX < <(aws ec2 describe-instances \
  --region ${REGION_NAME} \
  --instance-ids $(ec2-metadata --quiet -i) \
  --query 'Reservations[0].Instances[0].[SubnetId,SecurityGroups[0].GroupId,Placement.GroupName,KeyName]' \
  --output text)

## 修改 variables.tf 内容 
sed -i "s/REGION_NAME_XXX/${REGION_NAME}/g" variables.tf
sed -i "s/SUBNET_ID_XXX/${SUBNET_ID_XXX}/g" variables.tf
sed -i "s/SG_ID_XXX/${SG_ID_XXX}/g" variables.tf
sed -i "s/INSTANCE_NAME_XXX/SUT_${SUT_NAME}/g" variables.tf
sed -i "s/INSTANCE_TYPE_XXX/${INSTANCE_TYPE}/g" variables.tf
sed -i "s/AMI_ID_XXX/${AMI_ID}/g" variables.tf
sed -i "s/USERDATA_FILE_XXX/userdata.sh/g" variables.tf
sed -i "s/KEY_NAME_XXX/${KEY_NAME_XXX}/g" variables.tf

## 修改 userdata.sh: 设置 AWC CLI 的 AK/SK
sed -i "s/SUT_XXX/${SUT_NAME}/g" userdata.sh
if grep -q "akxxx" userdata.sh && grep -q "skxxx" userdata.sh; then
    sed -i "s/akxxx/$(aws configure get aws_access_key_id)/g" userdata.sh
    sed -i "s/skxxx/$(aws configure get aws_secret_access_key)/g" userdata.sh
fi

## 修改 userdata.sh: 设置是否使用Cluster Placement Group
## USE_CPG 通过 调用脚本 launch-instances-single.sh 时传递过来 USE_CPG=1 表示使用 CPG， 否则不使用。
if [ "$USE_CPG" = "1" ] && [ -n "$PG_NAME_XXX" ]; then
  sed -i "s/PG_NAME_XXX/\"${PG_NAME_XXX}\"/g" variables.tf
else
  sed -i "s/PG_NAME_XXX/null/g" variables.tf
fi

## 使用 terraform 启动实例
terraform init
terraform plan
terraform apply --auto-approve || exit 128

echo "$0: Terraform completed."

INSTANCE_ID_WEB1=$(terraform output -raw instance_id_0)
INSTANCE_ID_WEB2=$(terraform output -raw instance_id_1)
INSTANCE_IP_WEB1=$(terraform output -raw instance_private_ip_0)
INSTANCE_IP_WEB2=$(terraform output -raw instance_private_ip_1)
INSTANCE_PUBLIC_IP_WEB1=$(terraform output -raw instance_public_ip_0)
INSTANCE_PUBLIC_IP_WEB2=$(terraform output -raw instance_public_ip_1)
echo "export INSTANCE_ID_WEB1=${INSTANCE_ID_WEB1}" >> /tmp/temp-setting
echo "export INSTANCE_ID_WEB2=${INSTANCE_ID_WEB2}" >> /tmp/temp-setting
echo "export INSTANCE_IP_WEB1=${INSTANCE_IP_WEB1}" >> /tmp/temp-setting
echo "export INSTANCE_IP_WEB2=${INSTANCE_IP_WEB2}" >> /tmp/temp-setting
echo "export INSTANCE_PUBLIC_IP_WEB1=${INSTANCE_PUBLIC_IP_WEB1}" >> /tmp/temp-setting
echo "export INSTANCE_PUBLIC_IP_WEB2=${INSTANCE_PUBLIC_IP_WEB2}" >> /tmp/temp-setting

# 保存 Benchmark 结果的 S3 桶名称
BENCHMARK_RESULT_BUCKET=$(aws s3 ls | awk '{print $3}' | grep ec2-core-benchmark | head -1)
if [ -z "$BENCHMARK_RESULT_BUCKET" ]; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    REGION=$(aws configure get region)
    BENCHMARK_RESULT_BUCKET="ec2-core-benchmark-${ACCOUNT_ID}"
    aws s3 mb "s3://${BENCHMARK_RESULT_BUCKET}" --region "${REGION}"
    echo "Created bucket: ${BENCHMARK_RESULT_BUCKET}"
else
    echo "Found bucket: ${BENCHMARK_RESULT_BUCKET}"
fi
echo "export BENCHMARK_RESULT_BUCKET=${BENCHMARK_RESULT_BUCKET}" >> /tmp/temp-setting

# 保存实例信息
cd ..
mv tf_cfg_${SUT_NAME}  tf_cfg_${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_WEB1}
cp /tmp/temp-setting tf_cfg_${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_WEB1}/temp-setting

# echo "$0: [$(date +%Y%m%d.%H%M%S)] Start waiting 300 seconds for NGINX WEBSERVER UserData completed."
# sleep 300

###################################################################################################
# 2. 创建 1 台 nginx-loadbalance
## 创建对应的 terraform 配置文件目录
cd ..
echo "$0: Launch 1 nginx loadbalance..."
SUT_NAME="nginx-loadbalance"
cd ${SUT_NAME}
rm -rf tf_cfg_${SUT_NAME}
cp -rf tf_cfg_template tf_cfg_${SUT_NAME}
cd tf_cfg_${SUT_NAME}

## 修改 variables.tf 内容 
sed -i "s/REGION_NAME_XXX/${REGION_NAME}/g" variables.tf
sed -i "s/SUBNET_ID_XXX/${SUBNET_ID_XXX}/g" variables.tf
sed -i "s/SG_ID_XXX/${SG_ID_XXX}/g" variables.tf
sed -i "s/INSTANCE_NAME_XXX/SUT_${SUT_NAME}/g" variables.tf
sed -i "s/INSTANCE_TYPE_XXX/${INSTANCE_TYPE}/g" variables.tf
sed -i "s/AMI_ID_XXX/${AMI_ID}/g" variables.tf
sed -i "s/USERDATA_FILE_XXX/userdata.sh/g" variables.tf
sed -i "s/KEY_NAME_XXX/${KEY_NAME_XXX}/g" variables.tf

## 修改 userdata-xx.sh 的 SUT_NAME 
sed -i "s/SUT_XXX/${SUT_NAME}/g" userdata.sh
sed -i "s/INSTANCE_IP_WEB1_XXX/${INSTANCE_IP_WEB1}/g" userdata.sh
sed -i "s/INSTANCE_IP_WEB2_XXX/${INSTANCE_IP_WEB2}/g" userdata.sh

if grep -q "akxxx" userdata.sh && grep -q "skxxx" userdata.sh; then
    sed -i "s/akxxx/$(aws configure get aws_access_key_id)/g" userdata.sh
    sed -i "s/skxxx/$(aws configure get aws_secret_access_key)/g" userdata.sh
fi

## 修改 userdata.sh: 设置是否使用Cluster Placement Group
## USE_CPG 通过 调用脚本 launch-instances-single.sh 时传递过来 USE_cpg=1 表示使用 CPG， 否则不使用。
if [ "$USE_CPG" = "1" ] && [ -n "$PG_NAME_XXX" ]; then
  sed -i "s/PG_NAME_XXX/\"${PG_NAME_XXX}\"/g" variables.tf
else
  sed -i "s/PG_NAME_XXX/null/g" variables.tf
fi

## 使用 terraform 启动实例
terraform init
terraform plan
terraform apply --auto-approve || exit 128

echo "$0: Terraform completed."

INSTANCE_ID_LOADBALANCE=$(terraform output -raw instance_id)
INSTANCE_IP_LOADBALANCE=$(terraform output -raw instance_private_ip)
INSTANCE_PUBLIC_IP_LOADBALANCE=$(terraform output -raw instance_public_ip)
echo "export INSTANCE_ID_LOADBALANCE=${INSTANCE_ID_LOADBALANCE}" >> /tmp/temp-setting
echo "export INSTANCE_IP_LOADBALANCE=${INSTANCE_IP_LOADBALANCE}" >> /tmp/temp-setting
echo "export INSTANCE_PUBLIC_IP_LOADBALANCE=${INSTANCE_PUBLIC_IP_LOADBALANCE}" >> /tmp/temp-setting

# 保存 Benchmark 结果的 S3 桶名称
BENCHMARK_RESULT_BUCKET=$(aws s3 ls | awk '{print $3}' | grep ec2-core-benchmark | head -1)
if [ -z "$BENCHMARK_RESULT_BUCKET" ]; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    REGION=$(aws configure get region)
    BENCHMARK_RESULT_BUCKET="ec2-core-benchmark-${ACCOUNT_ID}"
    aws s3 mb "s3://${BENCHMARK_RESULT_BUCKET}" --region "${REGION}"
    echo "Created bucket: ${BENCHMARK_RESULT_BUCKET}"
else
    echo "Found bucket: ${BENCHMARK_RESULT_BUCKET}"
fi
echo "export BENCHMARK_RESULT_BUCKET=${BENCHMARK_RESULT_BUCKET}" >> /tmp/temp-setting

# 保存实例信息
cd ..
mv tf_cfg_${SUT_NAME}  tf_cfg_${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_LOADBALANCE}
cp /tmp/temp-setting tf_cfg_${SUT_NAME}_${INSTANCE_TYPE}_${OS_TYPE}_${INSTANCE_IP_LOADBALANCE}/temp-setting

