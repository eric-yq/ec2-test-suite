# more infra-iac/db/config.json
{
    "email": "e2b@example.com",
    "teamId": "458ff0aa-cc78-4e3c-b145-d56ecf8a613c",
    "accessToken": "sk_e2b_n51qjq3blea8jcxkfdilqc5j6ovewrfs",
    "teamApiKey": "e2b_mnnvx25h33es13fu7t7js44uoksxy4p5",
    "cloud": "aws",
    "region": "us-east-1"
}

# 模板 ID
## template-id（base-arm64）              hx2mpdts05mkl53hjw9f
## template-id（code-interpreter-arm64）  xxx
## template-id（desktop-arm64）           xxx

# 创建sandbox
curl -X POST \
 https://api.e2b-arm.daworld.shop/sandboxes \
 -H "X-API-Key: e2b_mnnvx25h33es13fu7t7js44uoksxy4p5" \
 -H 'Content-Type: application/json' \
 -d '{
        "templateID": "hx2mpdts05mkl53hjw9f",
        "timeout": 3600,
        "autoPause": true,
        "envVars": {
          "E2B_INFRA_ARCHITECTURE": "Arm64"
        },
        "metadata": {
            "CLIENT_CLUSTER_INSTANCE_TYPE": "c7g.metal"
        }
 }'
 
#################################################
# Installation Guide: https://e2b.dev/docs/cli
# For macOS
# brew install e2b

# For  Ubuntu
# apt install npm
# npm i -g @e2b/cli

# Export environment variables
export E2B_API_KEY=e2b_mnnvx25h33es13fu7t7js44uoksxy4p5
export E2B_ACCESS_TOKEN=sk_e2b_n51qjq3blea8jcxkfdilqc5j6ovewrfs
export E2B_DOMAIN="e2b-arm.daworld.shop"

# Common E2B CLI commands
# List all sandboxes
e2b sandbox list
 
# Connect to a sandbox
e2b sandbox connect <sandbox-id>
 
# Kill a sandbox
e2b sandbox kill <sandbox-id>
e2b sandbox kill --all

##################################################################################################
# Ubuntu 22.04
### 执行 https://github.com/aws-samples/sample-e2b-on-aws/tree/main/test_use_case 
git clone https://github.com/aws-samples/sample-e2b-on-aws.git
cd sample-e2b-on-aws/test_use_case

# 编辑 .env
cp .env.example .env

# 安装依赖
apt update
apt install -y build-essential pkg-config libgtk-3-dev libwebkit2gtk-4.0-dev python3-dev

curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python3 get-pip.py
pip3 install pytest dotenv e2b==1.4.0  e2b_code_interpreter e2b_desktop webview

# 执行用例
python3 -m pytest test_e2b_sdk.py -v
python3 test_code_interpreter.py
python3 test_e2b_desktop.py



#############################################################################################
# 构建 arm64 架构的 e2bdev/base:latest 测试镜像,  on BastionInsance-for-arm
# 参考 https://github.com/e2b-dev/E2B/tree/main/templates/base

## 1. 下载代码库
# 克隆仓库
cd ~
git clone https://github.com/e2b-dev/E2B.git

## 2. 进入 template 目录并构建 Docker 镜像
# 进入 template 目录
cd E2B/templates/base
# 构建 Docker 镜像并打标签
docker build -f e2b.Dockerfile -t e2bdev/base:latest .
docker image ls

## 3. 登录到 AWS ECR
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(cloud-init query region)
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

## 4. 给镜像打 ECR 标签
# 为镜像添加 ECR 仓库标签
docker tag e2bdev/base:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/e2bdev/base:latest

## 5. 推送镜像到 ECR
# 创建repo
aws ecr create-repository --repository-name e2bdev/base --region $AWS_REGION
# 推送镜像到 ECR
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/e2bdev/base:latest


#############################################################################################
# 构建 arm64 架构的 e2bdev/code-interpreter-arm64:latest 测试镜像,  on BastionInsance-for-arm

# 下载代码并构建推送 Docker 镜像到 ECR 的完整步骤

## 1. 下载代码库
# 克隆仓库
git clone https://github.com/e2b-dev/code-interpreter.git

## 2. 进入 template 目录并构建 Docker 镜像
# 进入 template 目录
cd code-interpreter/template
# yuanquan: 修改Dockerfile中架构相关代码
sed -i.bak "s/amd64/arm64/g" Dockerfile
# 构建 Docker 镜像并打标签
docker build -t e2bdev/code-interpreter-arm64:latest .
docker image ls
# REPOSITORY                        TAG     IMAGE ID      CREATED             SIZE
# e2bdev/code-interpreter-arm64  latest  881f2088cda4  About a minute ago  3.77GB

## 3. 登录到 AWS ECR
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(cloud-init query region)
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

## 4. 给镜像打 ECR 标签
docker tag e2bdev/code-interpreter-arm64:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/e2bdev/code-interpreter-arm64:latest

## 5. 推送镜像到 ECR
# 创建repo
aws ecr create-repository --repository-name e2bdev/code-interpreter-arm64 --region $AWS_REGION
# 推送镜像到 ECR
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/e2bdev/code-interpreter-arm64:latest

## 注意事项
# 1. 确保您已安装 AWS CLI 并已配置好凭证
# 2. 确保您有足够的权限访问该 ECR 仓库
# 3. 如果 ECR 仓库不存在，需要先创建：
#    aws ecr create-repository --repository-name e2bdev/code-interpreter-arm-test --region us-east-1
# 4. 如果您在 ARM 架构的机器上构建，镜像将自动为 ARM 架构。如果需要跨平台构建，可以使用 Docker BuildKit 和 `--platform` 参数：
#    docker buildx build --platform linux/arm64 -t e2bdev/code-interpreter-arm-test:latest .
# 
# 以上命令按顺序执行即可完成从代码下载到镜像推送的全部流程。
# 

#############################################################################################
# 构建 arm64 架构的 e2bdev/desktop-arm64:latest 测试镜像,  on BastionInsance-for-arm

# 下载代码并构建推送 Docker 镜像到 ECR 的完整步骤

## 1. 下载代码库
# 克隆仓库
git clone https://github.com/e2b-dev/desktop.git

## 2. 进入 template 目录并构建 Docker 镜像
# 进入 template 目录
cd desktop/template
# 修改Dockerfile中架构相关代码
sed -i.bak "s/amd64/arm64/g" e2b.Dockerfile
# 构建 Docker 镜像并打标签
docker build -f e2b.Dockerfile -t e2bdev/desktop-arm64:latest .
docker image ls
# REPOSITORY            TAG       IMAGE ID       CREATED          SIZE
# e2bdev/desktop-arm64  latest    9d87326edacc   58 seconds ago   3.46GB

## 3. 登录到 AWS ECR
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(cloud-init query region)
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

## 4. 给镜像打 ECR 标签
docker tag e2bdev/desktop-arm64:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/e2bdev/desktop-arm64:latest

## 5. 推送镜像到 ECR
# 创建repo
aws ecr create-repository --repository-name e2bdev/desktop-arm64 --region $AWS_REGION
# 推送镜像到 ECR
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/e2bdev/desktop-arm64:latest

