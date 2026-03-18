# 将官方镜像推送到 ECR
# macos 上 colima+docker 如果无法从 dockerhub 拉取镜像(可能是公司安全限制)
# 可以在 EC2 上先拉取 arm-mcp:latest 镜像，再推送到 ECR 保存。

REGION=$(cloud-init query region)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URL=${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com
# 或者
REGION=$(aws configure get default.region)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URL=${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com
echo $ECR_URL

1. 创建 ECR 仓库（如果还没有）
aws ecr create-repository --repository-name arm-mcp --region ${REGION}

2. 登录 ECR
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${ECR_URL}

3. Tag 并推送
docker tag armlimited/arm-mcp:latest ${ECR_URL}/arm-mcp:latest
docker push ${ECR_URL}/arm-mcp:latest

4. 拉取镜像
docker pull ${ECR_URL}/arm-mcp:latest