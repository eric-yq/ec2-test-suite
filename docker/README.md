# 启动容器:

首先启动一台 EC2 实例，例如 c6i.4xlarge，建议使用 Amazon Linux 2023，EBS 为 20G gp3。
登录到 EC2 实例进行必要的软件安装和配置：

```bash
sudo yum update
sudo yum install -y git docker
sudo systemctl start  docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
newgrp docker

# 配置 awscli......
aws_ak_value="AKXXX"
aws_sk_value="SKYYY"
aws_region_name=$(cloud-init query region)
aws configure set aws_access_key_id ${aws_ak_value}
aws configure set aws_secret_access_key ${aws_sk_value}
aws configure set default.region ${aws_region_name}
#aws_s3_bucket_name="s3://..."

# 从 ECR 存储库拉起镜像，启动容器
cd ~
git clone https://github.com/eric-yq/ec2-test-suite.git
docker pull public.ecr.aws/i6s7y0d7/ec2-loadgen:latest-amd64
docker run -dit --name loadgen --restart=always \
  -v ${HOME}/.aws:/root/.aws:ro \
  -v /run/cloud-init:/run/cloud-init \
  -v ${HOME}/ec2-test-suite:/root/ec2-test-suite \
  public.ecr.aws/i6s7y0d7/ec2-loadgen:latest-amd64

# 进入容器：
docker attach loadgen
# 登出容器：macos 快捷键为Shift+Ctrl+P，Q 组合键，
# 此时登出时，再次 attach 还看到相同的路径和进程状态。

```