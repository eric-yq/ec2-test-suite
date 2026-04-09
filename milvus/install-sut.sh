#!/bin/bash

yum install -yq docker git htop python3-pip
pip3 install dool
sleep 10

systemctl enable docker
systemctl start  docker

# 安装 local benchmark 所需要的工具
yum install -yq python3.13 python3.13-pip python3.13-devel gcc
pip3.13 install vectordb-bench ujson

ARCH=$(arch)
curl -SL https://github.com/docker/compose/releases/download/v2.12.2/docker-compose-linux-${ARCH} \
      -o /usr/bin/docker-compose
chmod +x /usr/bin/docker-compose

ver="v2.6.13"
# ver="v2.6.5"
mkdir /root/milvus && cd /root/milvus
wget https://github.com/milvus-io/milvus/releases/download/${ver}/milvus-standalone-docker-compose.yml \
  -O docker-compose.yml

## 启动 milvus 容器
docker-compose up -d
sleep 90

## 查看状态
docker-compose ps

# 启动 dool 监控
cd /tmp/ && python3 -m http.server 9527 &
DOOL_FILE="/tmp/dool-sut.txt"
nohup dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60 \
  1> ${DOOL_FILE} 2>&1 &

