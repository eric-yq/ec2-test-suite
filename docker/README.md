# 启动容器:

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

# 从 ECR PUBLIC 存储库拉起镜像
docker pull public.ecr.aws/i6s7y0d7/ec2-loadgen
docker run -it --rm --name loadgen  \
  -v ~/.aws:/root/.aws:ro\
  -v /run/cloud-init:/run/cloud-init\
  -v /root/ec2-test-suite:/root/ec2-test-suite\
  loadgen-tools:latest-amd64
```