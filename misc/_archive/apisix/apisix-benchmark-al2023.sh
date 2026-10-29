#!/bin/bash

## 先做镜像，在 HK region. 使用 root 用户登录

yum update -y

## 安装 apisix, redis, valkey 

##################################################################################################
## apisix
# 安装开发工具集
yum group install -yq "Development Tools"
yum install -yq gcc gcc-c++ make pcre pcre-devel zlib zlib-devel openssl openssl-devel gd gd-devel \
  libxml2 libxml2-devel libxslt libxslt-devel lua lua-devel libxcrypt-compat

# 安装 etcd
if [[ $(arch) == "x86_64" ]]; then
    ARCH="amd64"
else
    ARCH="arm64"
fi
cd ~
ETCD_VERSION='3.5.4'
wget https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-$ARCH.tar.gz
tar -xvf etcd-v${ETCD_VERSION}-linux-$ARCH.tar.gz && \
  cd etcd-v${ETCD_VERSION}-linux-$ARCH && \
  cp -a etcd etcdctl /usr/bin/
# nohup etcd >/tmp/etcd.log 2>&1 &
## 创建 systemd 服务文件：
cat << EOF > /etc/systemd/system/etcd.service
[Unit]
Description=etcd key-value store
Documentation=https://github.com/etcd-io/etcd
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

## 启用并启动服务：
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd
## 检查状态：
systemctl status etcd

## 安装 OpenResty 和 apisix, 使用 ecs-user 用户
cd ~
APISIX_VERSION='3.9.1'
# cd apisix-${APISIX_VERSION}
# sed -i.bak "s/LUAROCKS_VER=3.8.0/LUAROCKS_VER=3.12.0/g" utils/linux-install-luarocks.sh
# sed -i.bak "s/lualdap = 1.2.6-1/lualdap = 1.4.0/g" apisix-master-0.rockspec 
# sed -i.bak "s/sudo yum-config-manager/#sudo yum-config-manager/g" utils/install-dependencies.sh 
# utils/linux-install-luarocks.sh
# make deps -j && make install
yum install -y https://repos.apiseven.com/packages/centos/apache-apisix-repo-1.0-1.noarch.rpm
sed -i.bak "s/\$releasever/8/g" /etc/yum.repos.d/apache-apisix.repo
sed -i.bak "s/\$releasever/8/g" /etc/yum.repos.d/openresty.repo
yum clean all
yum makecache
yum install -y apisix-$APISIX_VERSION
# apisix init
# apisix start

# 安装 wrk
cd ~
wget https://github.com/wg/wrk/archive/refs/tags/4.2.0.tar.gz
tar zxf 4.2.0.tar.gz
cd wrk-4.2.0
make -j
ln -s ~/wrk-4.2.0/wrk /usr/bin/wrk
wrk -v

# benchmark
cd /opt         ## benchmark不能在/root 目录下执行。。。。
APISIX_VERSION='3.9.1'
git clone --depth 1 --branch ${APISIX_VERSION} https://github.com/apache/apisix.git apisix-${APISIX_VERSION}
cd apisix-${APISIX_VERSION}
sed -i.bak "s/LUAROCKS_VER=3.8.0/LUAROCKS_VER=3.12.0/g" utils/linux-install-luarocks.sh
sed -i.bak "s/lualdap = 1.2.6-1/lualdap = 1.4.0/g" apisix-master-0.rockspec 
bash utils/linux-install-luarocks.sh
# sed -i.bak "s/sudo yum-config-manager/#sudo yum-config-manager/g" utils/install-dependencies.sh
make deps -j && make install
sed -i.bak "s/bash -x/bash/g"   ./benchmark/run.sh
sed -i "s/wrk -d 5/wrk -d 60/g" ./benchmark/run.sh

## run benchmark
ulimit -n 65535
rm -rf logs/* benchmark/fake-apisix/logs/*  && df -h
./benchmark/run.sh 1 && sleep 10
./benchmark/run.sh 2 && sleep 10
rm -rf logs/* benchmark/fake-apisix/logs/*  && df -h
./benchmark/run.sh 4 && sleep 10
./benchmark/run.sh 6 && sleep 10
