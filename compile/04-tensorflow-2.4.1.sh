#!/bin/bash

sudo su - root

# 创建虚拟环境：AL2 自带 Python 3.7.16

python3 -m venv my_app/env
source ~/my_app/env/bin/activate
python --version
pip install pip --upgrade
yum groupinstall -y -q "Development Tools"
yum -y install python3-devel

# 1. 安装 pythainlp==2.3.2
pip install pythainlp==2.3.2

# 2. 安装 mecab-python3==1.0.8
pip install mecab-python3==1.0.8

# 3. 安装（编译）tensorflow==2.4.1
pip install -U pip numpy wheel
pip install -U keras_preprocessing --no-deps
wget https://github.com/tensorflow/tensorflow/archive/refs/tags/v2.4.1.tar.gz
tar zxf v2.4.1.tar.gz 
cd tensorflow-2.4.1
## 查看支持的 bazel 版本, bazel 要在 3.1.0 和 3.99.0 之间
grep _TF_MIN_BAZEL_VERSION configure.py 
### _TF_MIN_BAZEL_VERSION = '3.1.0'
grep _TF_MAX_BAZEL_VERSION configure.py 
### _TF_MAX_BAZEL_VERSION = '3.99.0'
## 下载 bazel（用于构建），这里选择 4.0 之前的最后一个版本 3.7.2
wget https://github.com/bazelbuild/bazel/releases/download/3.7.2/bazel-3.7.2-linux-arm64 -O /usr/local/bin/bazel
chmod +x /usr/local/bin/bazel
bazel --version

## 配置
./configure
# Do you wish to build TensorFlow with ROCm support? [y/N]: N
# Do you wish to build TensorFlow with CUDA support? [y/N]: N
# Do you wish to download a fresh release of clang? (Experimental) [y/N]: N
# Please specify optimization flags to use during compilation when bazel option "--config=opt" is specified [Default is -Wno-sign-compare]: 
# -Ofast -mcpu=neoverse-v1
# Would you like to interactively configure ./WORKSPACE for Android builds? [y/N]: N

## 构建 pip 软件包
bazel build --config=v2 --config=mkl_aarch64 //tensorflow/tools/pip_package:build_pip_package
  
## 查看输出
## ll ./bazel-bin/tensorflow/tools/pip_package/build_pip_package

## 构建软件包
./bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp/tensorflow_pkg

## 查看输出
## ls /tmp/tensorflow_pkg

## 安装 hdf5（后面的 h5py 依赖 libhdf5.so，
## 所以，这里构建好的 tensorflow wheel 包拿到其他实例进行安装的话，也需要先装 hdf5）
cd ~
wget https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5-1_10_7.tar.gz
tar zxf hdf5-1_10_7.tar.gz
cd hdf5-hdf5-1_10_7/
./configure --enable-cxx --prefix=/usr/local/hdf5
make -j$(nproc)
make install 
## 安装 h5py（依赖 hdf5）
cd ~
pip install Cython==0.29.36
HDF5_DIR=/usr/local/hdf5 pip install --no-binary=h5py h5py==2.10.0

## 安装 TensorFlow 2.4.1， wheel 在 /tmp/tensorflow_pkg 路径下。
pip install /tmp/tensorflow_pkg/tensorflow-2.4.1-cp37-cp37m-linux_aarch64.whl

## 简单验证
cd ~
pip install numpy --upgrade
python show tensorflow

python
>>> import tensorflow as tf
>>> tf.compat.v1.disable_eager_execution()
>>> hello=tf.constant('Hello TensorFlow 2.4.1')
>>> sess=tf.compat.v1.Session()
2024-06-14 23:57:49.575284: I tensorflow/compiler/jit/xla_cpu_device.cc:41] Not creating XLA devices, tf_xla_enable_xla_devices not set
>>> print(sess.run(hello))
2024-06-14 23:58:02.983457: I tensorflow/compiler/mlir/mlir_graph_optimization_pass.cc:196] None of the MLIR optimization passes are enabled (registered 0 passes)
2024-06-14 23:58:02.984212: W tensorflow/core/platform/profile_utils/cpu_utils.cc:116] Failed to find bogomips or clock in /proc/cpuinfo; cannot determine CPU frequency
b'Hello TensorFlow 2.4.1'
>>> 
