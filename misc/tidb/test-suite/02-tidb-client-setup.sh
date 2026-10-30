#!/bin/bash 

# 用法：INSTANCE_ID=i-xxxxxx bash 02-tidb-client-setup.sh
# 说明：通过环境变量向脚本传入一个 INSTANCE_ID, 然后获取到这个实例的子网 ID，和安全组 ID，
# 在相同的子网 ID 和安全组 ID 配置下，创建一个 tidb-client 为名称的和实例（类型为 c8i.4xlarge，EBS 40G gp3）

set -euo pipefail

if [ -z "$INSTANCE_ID" ] ; then
  echo "❌ 脚本参数必须传入 INSTANCE_ID "; exit 1
fi

REGION="${REGION:-us-east-2}"
TIDB_CLIENT_SIZE="${TIDB_CLIENT_SIZE:-c8i.4xlarge}"

# 1. 获取源实例的子网、安全组、密钥对
read SUBNET_ID KEY_NAME < <(aws ec2 describe-instances --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].[SubnetId,KeyName]' --output text)

SG_IDS=$(aws ec2 describe-instances --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].SecurityGroups[].GroupId' --output text)

####################################################################################
# 根据INSTANCE_ID获取 EKS 相关信息
# 1.1 从实例标签中获取 EKS 集群名（按优先级依次尝试）
#    - eks:cluster-name           托管节点组
#    - eks:eks-cluster-name       Karpenter / Auto Mode 节点
#    - kubernetes.io/cluster/<名>  通用标签，集群名在 key 里
get_tag() {
  aws ec2 describe-tags --region "$REGION" \
    --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=\$1" \
    --query 'Tags[0].Value' --output text
}

CLUSTER_NAME=$(get_tag "eks:cluster-name")
[ "$CLUSTER_NAME" = "None" ] && CLUSTER_NAME=$(get_tag "eks:eks-cluster-name")
if [ "$CLUSTER_NAME" = "None" ]; then
  CLUSTER_NAME=$(aws ec2 describe-tags --region "$REGION" \
    --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=kubernetes.io/cluster/*" \
    --query 'Tags[0].Key' --output text | sed 's#kubernetes.io/cluster/##')
fi

if [ -z "$CLUSTER_NAME" ] || [ "$CLUSTER_NAME" = "None" ]; then
  echo "❌ 实例 $INSTANCE_ID 上没有找到 EKS 集群标签，它可能不是 EKS 节点"; exit 1
fi
echo "EKS 集群: $CLUSTER_NAME"

# 1.2 配置该集群的 kubeconfig，用独立的 alias 作为 context，不影响当前默认 context
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME" \
  --alias "$CLUSTER_NAME" >/dev/null

# 1.3 用这个集群的 context 获取 TiDB 的 LB 地址，地址未分配时等待重试
until tidb_host=$(kubectl --context "$CLUSTER_NAME" get svc basic-tidb \
        -n "tidb-${INSTANCE_FAMILY}" \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}') \
      && [ -n "$tidb_host" ]; do
  echo "等待 LB 地址..."; sleep 10
done
echo "TIDB_HOST: $tidb_host"
####################################################################################

# 2. 获取最新的 AL2023 x86_64 AMI（c8i 是 Intel 机型，必须用 x86 镜像）
AMI_ID=$(aws ssm get-parameter --region "$REGION" \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameter.Value' --output text)

echo "Subnet: $SUBNET_ID | SG: $SG_IDS | Key: $KEY_NAME | AMI_ID: $AMI_ID"

# 3. 生成 userdata
# 用带引号的 'EOF'，让 userdata 原样写入文件，$ 不会在本地被展开
# tidb_host 先用占位符代替，最后再用 sed 替换成真实值
USERDATA_FILE=$(mktemp /tmp/tidb-client-userdata.XXXX.sh)

cat > "$USERDATA_FILE" << 'EOF'
#!/bin/bash
exec > /var/log/tidb-client-init.log 2>&1   # 初始化日志，便于排查
set -x
export HOME=/root                            # cloud-init 环境下没有 HOME，需要手动设置
cd /root

yum update -yq
yum install -yq python3-pip htop
pip3 install dool

# MySQL 客户端
rpm -Uvh https://repo.mysql.com/mysql80-community-release-el9.rpm
rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2023
yum install -yq mysql-community-client

# 环境变量（写入 root 的 profile）
cat >> /root/.bash_profile << 'EOP'
export tidb_host="__TIDB_HOST__"
export sf=300
export wares=1000
EOP
source /root/.bash_profile

# 测试 mysql 客户端远程访问（失败不影响后续步骤）
mysql -h "${tidb_host}" -P 4000 -u root -e "show databases;" || echo "WARN: TiDB 连接失败，请检查安全组 4000 端口"

# 安装 TiUP
curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh
source /root/.bash_profile
export PATH=/root/.tiup/bin:$PATH
tiup install playground
tiup install bench

echo "tidb-client init done"
EOF

sed -i "s#__TIDB_HOST__#${tidb_host}#g" "$USERDATA_FILE"

# 4. 创建 tidb-client 
NEW_ID=$(aws ec2 run-instances --region "$REGION" \
  --image-id "$AMI_ID" \
  --instance-type c8i.4xlarge \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids $SG_IDS \
  --key-name "$KEY_NAME" \
  --user-data "file://$USERDATA_FILE" \
  --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":40,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=tidb-client}]' \
  --query 'Instances[0].InstanceId' --output text)

echo "已创建 tidb-client: $NEW_ID"
aws ec2 wait instance-running --region "$REGION" --instance-ids "$NEW_ID"
aws ec2 describe-instances --region "$REGION" --instance-ids "$NEW_ID" \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text

rm -f "$USERDATA_FILE"
