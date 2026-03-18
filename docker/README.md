构建镜像

```bash
yum install -y git docker
systemctl start docker
# 配置 awscli......

git clone https://github.com/eric-yq/ec2-test-suite.git
cd ec2-test-suite/docker

# 推送到私有仓库
PUSH_TO_ECR=private ./build.sh

# 推送到公有仓库
PUSH_TO_ECR=publich ./build.sh

# 同时推送 私有和公有仓库
PUSH_TO_ECR=both ./build.sh

```

启动容器:

首先启动一台 EC2 实例，例如 c6i.4xlarge，建议使用 Amazon Linux 2023。
登录到 EC2 实例进行必要的安装和配置：

```bash
yum update
yum install -y git docker
systemctl start  docker
systemctl enable docker

# 配置 awscli......
aws_ak_value="AKXXX"
aws_sk_value="SKYYY"
aws_region_name=$(cloud-init query region)
aws configure set aws_access_key_id ${aws_ak_value}
aws configure set aws_secret_access_key ${aws_sk_value}
aws configure set default.region ${aws_region_name}
#aws_s3_bucket_name="s3://..."

# 拉取进项
docker run -it --rm --name loadgen  \
  -v ~/.aws:/root/.aws:ro\
  -v /run/cloud-init:/run/cloud-init\
  -v /root/ec2-test-suite:/root/ec2-test-suite\
  loadgen-tools:latest-amd64
```