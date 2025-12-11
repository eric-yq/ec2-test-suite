#!/bin/bash

# Amazon Linux 2023

sudo su - root

# 启动 Docker 服务
yum install -y git docker python3-pip
pip3 install dool
systemctl enable docker
systemctl start docker

# 配置 AWS CLI
aws_ak_value="xxx"
aws_sk_value="+xxx"
aws_region_name=$(cloud-init query region)
aws configure set aws_access_key_id ${aws_ak_value}
aws configure set aws_secret_access_key ${aws_sk_value}
aws configure set default.region ${aws_region_name}
aws_s3_bucket_name="s3://ec2-core-benchmark-ericyq"

# 拉镜像
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 763104351884.dkr.ecr.us-east-1.amazonaws.com
IAMGE_NAME=763104351884.dkr.ecr.us-east-1.amazonaws.com/pytorch-inference$([ "$(uname -m)" == "x86_64" ] && echo "" || echo "-arm64"):2.6.0-cpu-py312-ubuntu22.04-ec2
docker pull ${IAMGE_NAME}

# 启动容器
docker run -d --name pytorch-container --restart unless-stopped ${IAMGE_NAME} tail -f /dev/null

# 进入容器
docker exec -it pytorch-container /bin/bash
# 可以使用exit 退出容器，
# 下面是容器中里面的脚本：
git clone https://github.com/pytorch/benchmark.git
cd benchmark
python3 install.py nvidia_deeprecommender
python3 run_benchmark.py cpu --model nvidia_deeprecommender \
  --test eval --torchdynamo inductor --freeze_prepack_weights --metrics="latencies,cpu_peak_mem"

# 查看结果
cd /benchmark/.userbenchmark/cpu
ls -tr metric*.json

#########################################################################################################

# on the host machine

# ARM
python3 run_full_benchmark.py --arm64 --model nvidia_deeprecommender \
    --batch-sizes "1,2,4,8,16,32,64,128,256,512,1024" \
    --niter 30 --test eval --metrics="latencies,cpu_peak_mem"

# Intel
python3 run_full_benchmark.py --model nvidia_deeprecommender \
    --batch-sizes "1,2,4,8,16,32,64,128,256,512,1024" \
    --niter 30 --test eval --metrics="latencies,cpu_peak_mem"

# 其他可以使用的选项： --force-setup

# 原始结果在 /benchmark/.userbenchmark/cpu 目录下