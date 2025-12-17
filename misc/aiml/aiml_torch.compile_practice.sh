#!/bin/bash
# OS: Ubuntu 22.04 

# Reference:  这里使用 TorchBench framework.
# https://aws.amazon.com/blogs/machine-learning/accelerated-pytorch-inference-with-torch-compile-on-aws-graviton-processors/

sudo su - root

apt update
apt install -y build-essential vim unzip git lsb-release grub2-common net-tools dmidecode hwloc \
  util-linux numactl screen wget zip p7zip php php-cli php-json php-xml php-curl python3-pip python3-dev \
  cargo libssl-dev libcurl4-openssl-dev libpcap-dev liblzma-dev scons 
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
./configure --enable-cxx --prefix=/usr/ && \
make -j$(nproc) && \
make install 
find /usr/ -name "*hdf5*"


###########################################################################################
# 创建执行 benchmark 的虚拟环境
# TorchBench benchmarking scripts
# TorchBench is a collection of open source benchmarks used to evaluate PyTorch performance.
# We benchmarked 45 models using the scripts from the TorchBench repo. 
# Following code shows how to run the scripts for the eager mode and the compile mode with inductor backend.
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

cd ~
testname="torch.compile.bench"
conda create -y -q -n ${testname} python=3.11
conda activate $testname

# Install PyTorch and extensions
pip install torch==2.3.1 torchvision==0.18.1 torchaudio==2.3.1

# Install the dependencies
apt install -y libgl1-mesa-glx libpangocairo-1.0-0 libgeos-dev
# pip install psutil numpy transformers pynvml numba onnx onnxruntime scikit-learn timm effdet gym doctr opencv-python h5py==3.10.0 python-doctr
pip install psutil numpy transformers nvidia-ml-py numba onnx onnxruntime scikit-learn timm effdet gym doctr opencv-python h5py==3.10.0 python-doctr


# Clone pytorch benchmark repo
git clone https://github.com/pytorch/benchmark.git
cd benchmark
# PyTorch benchmark repo doesn't have any release tags. So,
# listing the commit we used for collecting the performance numbers
git checkout 9a5e4137299741e1b6fb7aa7f5a6a853e5dd2295
# Setup the models
python3 install.py

vi run.sh # 将下面的内容粘贴进去并保存退出
#!/bin/bash

instance_type=$(ec2metadata --instance-type)
# Enable the fast math GEMM kernels, to accelerate fp32 inference with bfloat16 gemm
export DNNL_DEFAULT_FPMATH_MODE=BF16
# Enable Linux Transparent Huge Page (THP) allocations,
# to reduce the tensor memory allocation latency
export THP_MEM_ALLOC_ENABLE=1
# Set LRU Cache capacity to cache the primitives and avoid redundant
# memory allocations
export LRU_CACHE_CAPACITY=1024
# Set OMP_NUM_THREADS to number of vcpus
export OMP_NUM_THREADS=$(nproc)

echo "[Info] DNNL_DEFAULT_FPMATH_MODE=$DNNL_DEFAULT_FPMATH_MODE, THP_MEM_ALLOC_ENABLE=$THP_MEM_ALLOC_ENABLE,  LRU_CACHE_CAPACITY=$LRU_CACHE_CAPACITY"
# 222222...... Collect torch.compile mode performance with inductor backend and weights pre-packing enabled. 
# The results will be stored at .userbenchmark/cpu/metric-<timestamp>.json

models="BERT_pytorch,hf_Bert,hf_Bert_large,hf_GPT2,hf_Albert,hf_Bart,hf_BigBird,hf_DistilBert,hf_GPT2_large,dlrm,hf_T5,mnasnet1_0,mobilenet_v2,mobilenet_v3_large,squeezenet1_1,timm_efficientnet,shufflenet_v2_x1_0,timm_regnet,resnet50,soft_actor_critic,phlippe_densenet,resnet152,resnet18,resnext50_32x4d,densenet121,phlippe_resnet,doctr_det_predictor,timm_vovnet,alexnet,doctr_reco_predictor,vgg16,dcgan,yolov3,pytorch_stargan,hf_Longformer,timm_nfnet,timm_vision_transformer,timm_vision_transformer_large,nvidia_deeprecommender,demucs,tts_angular,hf_Reformer,pytorch_CycleGAN_and_pix2pix,functorch_dp_cifar10,pytorch_unet"

python3 run_benchmark.py cpu --model $models \
  --test eval --metrics="latencies,cpu_peak_mem" --torchdynamo inductor --freeze_prepack_weights \
  1> torch_compile_inductor_${instance_type}_$(date +%Y%m%d_%H%M%S).log 2>&1

#################################################################################################################
# 111111...... Colect eager mode performance using the following command. 
# The results will be stored at .userbenchmark/cpu/metric-<timestamp>.json.
models="BERT_pytorch,hf_Bert,hf_Bert_large,hf_GPT2,hf_Albert,hf_Bart,hf_BigBird,hf_DistilBert,hf_GPT2_large,dlrm,hf_T5,mnasnet1_0,mobilenet_v2,mobilenet_v3_large,squeezenet1_1,timm_efficientnet,shufflenet_v2_x1_0,timm_regnet,resnet50,soft_actor_critic,phlippe_densenet,resnet152,resnet18,resnext50_32x4d,densenet121,phlippe_resnet,doctr_det_predictor,timm_vovnet,alexnet,doctr_reco_predictor,vgg16,dcgan,yolov3,pytorch_stargan,hf_Longformer,timm_nfnet,timm_vision_transformer,timm_vision_transformer_large,nvidia_deeprecommender,demucs,tts_angular,hf_Reformer,pytorch_CycleGAN_and_pix2pix,functorch_dp_cifar10,pytorch_unet"
python3 run_benchmark.py cpu --model $models \
  --test eval --metrics="latencies,cpu_peak_mem"




