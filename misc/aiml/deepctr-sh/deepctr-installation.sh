#!/bin/bash

## Amazon Linux 2023

yum install -y git perf

# Install conda
cd /root/
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(arch).sh
bash Miniconda3-latest-Linux-$(arch).sh -b -p /root/miniconda3/
eval "$(/root/miniconda3/bin/conda shell.bash hook)"
conda init
source /root/.bashrc

# Create Python3.9 env: deepctr
testname="deepctr"
conda create -y -q -n ${testname} python=3.9
conda activate $testname

# Install dependency 
pip install onnxruntime==1.17.1
pip install numpy==1.26.4 pandas dool # deepctr need numpy 1.x

# Insatll DeepCTR
git clone https://github.com/shenweichen/DeepCTR.git
cd DeepCTR
python setup.py install
