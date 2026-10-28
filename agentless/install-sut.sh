#!/bin/bash

set -uo pipefail

# 安装 docker 和 uv
curl -LsSf https://astral.sh/uv/install.sh | sh
source /root/.local/bin/env
apt install -y docker.io
mkdir -p /root/.docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" \
  -o /root/.docker/cli-plugins/docker-compose
chmod +x /root/.docker/cli-plugins/docker-compose

# 构建镜像
cd /root/
git clone https://github.com/eric-yq/agentless-agent-bench-for-ec2.git
cd agentless-agent-bench-for-ec2
uv run main.py build
sleep 5

# 启动镜像
# 24xlarge使用 --each 2
uv run main.py warm --each 2
sleep 5

# 预热一轮
uv run main.py throughput --ncpu $(nproc) --each 2 --duration 60
sleep 10

# 并发跑 30 分钟
uv run main.py throughput --ncpu $(nproc) --each 2 --duration 1800
sleep 10

# 跑一轮串行
uv run main.py serial
sleep 5

###########################################################3
## 汇总结果并打包
cd /root/
instance_type=$(ec2-metadata --quiet --instance-type)
timestamp=$(date +%Y%m%d-%H%M%S)
archive="agentless_result_${instance_type}_${timestamp}"
mkdir -p ${archive}
cp /root/agentless-agent-bench-for-ec2/results/* ${archive}
tar czf ${archive}.tar.gz ${archive}/
aws_s3_bucket_name=$(aws s3 ls | awk '{print $3}' | grep ec2-core-benchmark | head -1)
aws s3 cp ${archive}.tar.gz s3://${aws_s3_bucket_name}/result_agentless/

# 停止实例
INSTANCE_ID=$(ec2-metadata --quiet --instance-id)
REGION_ID=$(cloud-init query region)
aws ec2 terminate-instances --instance-ids "${INSTANCE_ID}" --region "${REGION_ID}"
