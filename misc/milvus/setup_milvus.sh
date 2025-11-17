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



###############################################################################################
# 安装 vdbbench, m6i.2xlarge + AL2023

sudo su - root

## Need isntall Python 3.11 or above
dnf install -y python3.11 python3.11-pip python3.11-devel git gcc gcc-c++
python3.11 -V

## Install VectorDBBench
pip3.11 install vectordb-bench ujson
which init_bench

## Redirect /tmp/vectordb_bench to another location
mkdir -p /root/vectordb_bench
ln -s /root/vectordb_bench /tmp/vectordb_bench

## init benchmark tool，follow the prompt to enter web page
# init_bench

## 通过命令行进行测试
# screen -R ttt -L
instance_type="r8i.2xlarge"
ipaddr="172.31.11.93"
vectordbbench milvushnsw \
  --case-type Performance768D1M \
  --m 30 --ef-construction 360 --ef-search 100 \
  --task-label milvus-$instance_type \
  --uri http://$ipaddr:19530 
  