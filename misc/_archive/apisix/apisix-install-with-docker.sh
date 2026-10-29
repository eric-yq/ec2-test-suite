#!/bin/bash

## 安装docker
yum install -yq git docker python3-pip htop
pip3 install dool
systemctl enable --now docker
systemctl start docker

## 安装Docker compose
ARCH=$(arch)
curl -SL https://github.com/docker/compose/releases/download/v2.12.2/docker-compose-linux-${ARCH} -o /usr/bin/docker-compose
chmod +x /usr/bin/docker-compose

## 拉取 apisix docker 镜像并启动
git clone https://github.com/apache/apisix-docker.git
cd apisix-docker/example
if [ "$arch" = "aarch64" ]; then
    docker-compose -p docker-apisix -f docker-compose-arm64.yml up -d
elif [ "$arch" = "x86_64" ]; then
    docker-compose -p docker-apisix up -d
fi


