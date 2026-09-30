#!/bin/bash

# 1. 使用最新的 loadgen-seed AMI 启动 c8id.8xlarge 实例，有 1900G NVME 本地盘。
# 2. 执行下面操作：

# 设置磁盘lvm stripe
cd /root/
yum install -yq git
git clone https://github.com/eric-yq/ec2-test-suite.git
bash ec2-test-suite/tools/setup_nvme_instance_store.sh
# 如果有本地盘，脚本执行后挂载到 /data；如果没有本地盘，则脚本退出。

# 安装pbzip2 和 lbzip2，多线程解压缩工具
yum install -y gcc-c++ bzip2-devel make
cd /tmp
curl -LO https://github.com/kjn/lbzip2/releases/download/v2.5/lbzip2-2.5.tar.gz
tar xzf pbzip2-1.1.13.tar.gz && cd pbzip2-1.1.13
make -j$(nproc)
sudo install -m755 pbzip2 /usr/local/bin/
# pbzip2 用同一个二进制提供 pbunzip2 / pbzcat
sudo ln -sf /usr/local/bin/pbzip2 /usr/local/bin/pbunzip2
sudo ln -sf /usr/local/bin/pbzip2 /usr/local/bin/pbzcat
pbzip2 --version
# lbzip2
cd /tmp
curl -LO https://github.com/kjn/lbzip2/releases/download/v2.5/lbzip2-2.5.tar.gz
tar xzf lbzip2-2.5.tar.gz && cd lbzip2-2.5
cp lib/fseterr.c lib/fseterr.c.orig
cat > lib/fseterr.c <<'EOF'
#include <config.h>
#include "fseterr.h"
#include <errno.h>
/* glibc 2.28+ 不再暴露 FILE 内部结构, 原实现的平台探测失效。
   lbzip2 并不依赖此函数的真实语义, 用最小实现绕过。 */
void fseterr (FILE *fp)
{
  /* 触发一次必然失败的写, 让 stdio 自己置上 error 标志 */
  if (fp != NULL)
    (void) fwrite ("", 1, 0, fp);
}
EOF
./configure --prefix=/usr/local && make -j$(nproc) && sudo make install
lbzip2 --version

######################## 安装 ESRally, 本地盘实例 ######################## 
echo "export ESROOTDISK=/data" >> /root/.bashrc
source .bashrc

# 设置 benchmark 目录在本地盘
mkdir -p $ESROOTDISK/esrally_benchmark /root/.rally 
ln -s $ESROOTDISK/esrally_benchmark /root/.rally/benchmarks

# 安装 ESRally 工具
yum install -y python3.13* git gcc gcc-c++ htop
pip3.13 install dool
pip3.13 install esrally # --ignore-installed requests
# pip3.13 install pytrec_eval==0.5 numpy==1.24.0 --upgrade --target /root/.rally/libs

# 获取 Rally Tracks
mkdir -p /root/.rally/benchmarks/tracks 
cd /root/.rally/benchmarks/tracks 
git clone https://github.com/elastic/rally-tracks.git
rm -rf default
cp -r rally-tracks/ default/

## 下载数据集
curl -LsSf https://astral.sh/uv/install.sh | sh
mkdir -p /root/.rally/benchmarks/data/
cd /root/.rally/benchmarks/data/
datasets="nyc_taxis http_logs wikipedia so_vector wiki_en_cohere_vector_int8 \
          msmarco-passage-ranking k8s_metrics sql joins"
for i in ${datasets}
do
    echo "[Info] Download Data Set: $i ... "
    uv run --python 3.13 /root/.rally/benchmarks/tracks/default/download.py $i 
    sleep 5
done
# 解压缩数据集
cd /root/.rally/benchmarks/data/
for i in $(ls -d */)
do
    cd $i && echo "[Info] Uncompress Data Set: $i ... "
    lbzip2 -dk -n $(nproc) *.bz2 && rm -rf *.bz2
    cd ..
done
