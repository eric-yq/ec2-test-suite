#!/bin/bash

# cloud-init script

dnf install -y docker git htop
sleep 10

systemctl start docker

ARCH=$(arch)
curl -SL https://github.com/docker/compose/releases/download/v2.12.2/docker-compose-linux-${ARCH} -o /usr/bin/docker-compose
chmod +x /usr/bin/docker-compose

mkdir /root/milvus
cd /root/milvus
wget https://github.com/milvus-io/milvus/releases/download/v2.4.5/milvus-standalone-docker-compose.yml -O docker-compose.yml

## 启动 milvus 容器
docker-compose up -d

## 查看状态
docker-compose ps


#（可选）安装 Web 管理工具
docker run -d -p 8000:3000 -e MILVUS_URL=$(hostname -i):19530 zilliz/attu:v2.4

