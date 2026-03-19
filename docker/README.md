# 启动容器:

首先启动一台 EC2 实例，作为管理平台
- 实例类型：例如，c7i.4xlarge，
- AMI：Amazon Linux 2023，
- EBS：gp3，20G
- Key Pair：选择常用或新建

实例启动成功后，通过 SSH 登录到 EC2 实例进行必要的软件安装和配置：

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

#################################################################
# 将当前实例的 Key Pair 的 pem 文件，上传到的 ~/.aws 目录，
# 后续在启动的 loadgen 容器中，会使用这个 key 采集 sut 的 dool 监控信息。
# 如果 ~/.aws 目录下没有 pem 文件，sut 的 dool 监控信息将采集失败。
#################################################################


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
# 登出容器：macos 快捷键为 Shift + Ctrl + P + Q 组合键；
# 此方式登出时，再次 attach 还看到相同的路径和进程状态。

# 进入容器后启动 benchmark:
cd /root/ec2-test-suite
# Single 型 Benchmark：specjbb15, ffmpeg, spark, pts 等
bash submit-benchmark-singles.sh specjbb15 r8g.4xlarge
bash submit-benchmark-singles.sh ffmpeg r8g.4xlarge
bash submit-benchmark-singles.sh spark r8g.4xlarge
bash submit-benchmark-singles.sh pts r8g.4xlarge
# C-S 型 Benchmark：redis, valkey, mysql-ebs, mongo, milvus, nginx 等
bash submit-benchmark-redis.sh r8g.2xlarge
bash submit-benchmark-valkey.sh r8g.2xlarge
bash submit-benchmark-mysql-hammerdb.sh r8g.2xlarge
bash submit-benchmark-mongo.sh r8g.2xlarge
bash submit-benchmark-milvus.sh r8g.2xlarge
bash submit-benchmark-nginx.sh r8g.2xlarge
# 1. 也可以选择使用 screen 执行。
# 2. ......
```