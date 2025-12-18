#!/bin/bash

# Amazon Linux 2023

yum group install -yq "Development Tools"
yum install -yq python3-pip htop git
pip3 install dool

# 安装conda
cd /root
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
  -O Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b   
echo "PATH=/root/miniconda3/bin:$PATH" >> /root/.bashrc
source ~/.bashrc

# 创建 scikit-learn 环境
conda create -n skl python=3.13 -y
conda init
source ~/.bashrc
conda activate skl

# 安装 scikit-learn 及相关依赖
pip install -U scikit-learn matplotlib

# 下载sciki-learn repo
cd /root
git clone https://github.com/scikit-learn/scikit-learn.git

# 进入benchmark目录
cd /root/scikit-learn/benchmarks
python3 bench_glm.py