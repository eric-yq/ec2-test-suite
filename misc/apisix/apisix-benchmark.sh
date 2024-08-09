#!/bin/bash

## ubuntu 22.04
# 架构变量
if [[ $(arch) == "x86_64" ]]; then
    ARCH="amd64"
else
    ARCH="arm64"
fi

apt install -y build-essential

# 安装 OpenResty
apt install -y --no-install-recommends wget gnupg ca-certificates
wget -O - https://openresty.org/package/pubkey.gpg --no-check-certificate | sudo gpg --dearmor -o /usr/share/keyrings/openresty.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/ubuntu $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/openresty.list > /dev/null
apt update
apt install -y openresty
openresty -v

# 安装 yq
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_$ARCH -O /usr/bin/yq
chmod +x /usr/bin/yq

# 安装 wrk
cd /opt
wget https://github.com/wg/wrk/archive/refs/tags/4.2.0.tar.gz
tar zxf 4.2.0.tar.gz
cd wrk-4.2.0
make -j
ln -s /opt/wrk-4.2.0/wrk /usr/bin/wrk
wrk -v

# 安装 etcd
cd /opt
ETCD_VERSION='3.5.4'
wget https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-$ARCH.tar.gz
tar -xvf etcd-v${ETCD_VERSION}-linux-$ARCH.tar.gz && \
  cd etcd-v${ETCD_VERSION}-linux-$ARCH && \
  cp -a etcd etcdctl /usr/bin/
nohup etcd >/tmp/etcd.log 2>&1 &
   
# 安装 apisix
cd /opt
APISIX_VERSION='3.9.1'
git clone --depth 1 --branch ${APISIX_VERSION} https://github.com/apache/apisix.git apisix-${APISIX_VERSION}
cd apisix-${APISIX_VERSION}
make deps -j
make install

# benchmark
sed -i.bak "s/bash -x/bash/g"   ./benchmark/run.sh
sed -i "s/wrk -d 5/wrk -d 60/g" ./benchmark/run.sh
ulimit -n 65535
rm -rf logs/* benchmark/fake-apisix/logs/*  && df -h
./benchmark/run.sh 1 && sleep 10
./benchmark/run.sh 2 && sleep 10
rm -rf logs/* benchmark/fake-apisix/logs/*  && df -h
./benchmark/run.sh 4 && sleep 10
./benchmark/run.sh 6 && sleep 10

