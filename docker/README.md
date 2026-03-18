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

```bash
docker run -it --rm --name loadgen  \
  -v ~/.aws:/root/.aws:ro\
  -v /run/cloud-init:/run/cloud-init\
  -v /root/ec2-test-suite:/root/ec2-test-suite\
  loadgen-tools:latest-amd64
```