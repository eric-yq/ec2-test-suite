#!/bin/bash
# OS: Ubuntu 22.04 

# Reference: 目的是和 onnxruntime==1.16 比较。
# https://aws.amazon.com/cn/blogs/machine-learning/accelerate-nlp-inference-with-onnx-runtime-on-aws-graviton-processors/

sudo su - root

apt update
apt install -y build-essential vim unzip git lsb-release grub2-common net-tools dmidecode hwloc util-linux numactl screen wget zip p7zip php php-cli php-json php-xml php-curl python3-pip python3-dev cargo libssl-dev libcurl4-openssl-dev libpcap-dev liblzma-dev scons

echo "------ INSTALLING PERFORMANCE TOOLS ------"
apt install -y sysstat hwloc tcpdump dstat htop iotop iftop nload stress-ng \
  linux-tools-$(uname -r) linux-headers-$(uname -r) linux-modules-extra-$(uname -r) bpfcc-tools

pip install --upgrade pip

## 更新 cmake
ARCH=$(arch) 
VER=3.29.6
wget https://github.com/Kitware/CMake/releases/download/v${VER}/cmake-${VER}-linux-${ARCH}.sh
sh cmake-${VER}-linux-${ARCH}.sh --skip-license --prefix=/usr
cmake -version

###########################################################################################
## 安装 conda（下面这些需要基于特定版本 python 进行测试。）
cd /root/
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(arch).sh
bash Miniconda3-latest-Linux-$(arch).sh -b -p /root/miniconda3/
eval "$(/root/miniconda3/bin/conda shell.bash hook)"
conda init
source /root/.bashrc

## 安装 hdf5，后面安装 h5py 时依赖 libhdf5.so
cd ~
wget https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5-1_10_7.tar.gz
tar zxf hdf5-1_10_7.tar.gz
cd hdf5-hdf5-1_10_7/
./configure --enable-cxx --prefix=/usr/
make -j$(nproc)
make install 
find /usr/ -name "*hdf5*"

###########################################################################################
# 创建执行 benchmark 的虚拟环境
testname="onnx.optimized"
conda create -y -q -n ${testname} python=3.11
conda activate $testname

# Install onnx and onnx runtime
# NOTE: We used 1.17.1 instead of 1.17.0 as it was the latest
# version available while collecting data for this post
python3 -m pip install onnx==1.15.0 onnxruntime==1.17.1

# Install the dependencies
python3 -m pip install transformers==4.38.1 torch==2.2.1 psutil==5.9.8 numpy==1.26.4

# Clone onnxruntime repo to get the benchmarking scripts
cd ~
git clone --recursive https://github.com/microsoft/onnxruntime.git
cd onnxruntime
git checkout 430a086f22684ad0020819dc3e7712f36fe9f016
cd onnxruntime/python/tools/transformers

# To run bert-large fp32 inference with bfloat16 fast math mode
python3 benchmark.py -m bert-large-uncased -p fp32 --enable_arm64_bfloat16_fastmath_mlas_gemm

# To run bert-base  fp32 inference with bfloat16 fast math mode
python3 benchmark.py -m bert-base-cased -p fp32 --enable_arm64_bfloat16_fastmath_mlas_gemm

# To run roberta-base  fp32 inference with bfloat16 fast math mode
python3 benchmark.py -m roberta-base -p fp32 --enable_arm64_bfloat16_fastmath_mlas_gemm

# To run gpt2  fp32 inference with bfloat16 fast math mode
python3 benchmark.py -m gpt2 -p fp32 --enable_arm64_bfloat16_fastmath_mlas_gemm

# To run bert-large int8 quantized inference
python3 benchmark.py -m bert-large-uncased -p int8

# To run bert-base int8 quantized inference
python3 benchmark.py -m bert-base-cased -p int8

# To run roberta-base int8 quantized inference
python3 benchmark.py -m roberta-base -p int8

# To run gpt2 int8 quantized inference
python3 benchmark.py -m gpt2 -p int8