#!/bin/bash

yum install -y docker git htop
sleep 10

systemctl enable docker
systemctl start  docker

ARCH=$(arch)
curl -SL https://github.com/docker/compose/releases/download/v2.12.2/docker-compose-linux-${ARCH} \
      -o /usr/bin/docker-compose
chmod +x /usr/bin/docker-compose

mkdir /root/milvus && cd /root/milvus
wget https://github.com/milvus-io/milvus/releases/download/v2.6.5/milvus-standalone-docker-compose.yml \
  -O docker-compose.yml

## 启动 milvus 容器
docker-compose up -d
sleep 60

## 查看状态
docker-compose ps