#!/bin/bash 

## https://dev.to/aws-heroes/intro-to-llama-on-graviton-1dc

# Ubuntu 24.04 

cd /root/

# Install any prerequisites
sudo apt update
sudo apt install make cmake -y gcc g++ -y build-essential

# Build llama.cpp
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make -j$(nproc)

# ##################################################################################################
# GPU 实例编译
# 安装 nvidia driver, cuda, cudnn 等
# wget https://raw.githubusercontent.com/eric-yq/ec2-test-suite/main/misc/ffmpeg_on_gpu/setup_gpu.sh
# bash setup_gpu.sh 
# NVCC=$(find / -name nvcc)
# NVCC_FOLDER=$(dirname $NVCC)
# echo "PATH=$PATH:$NVCC_FOLDER" >> ~/.bashrc
# source ~/.bashrc
# make -j $(nproc) GGML_CUDA=1

./llama-cli -h

# Set up a virtual environment for Python packages:
sudo apt install python-is-python3 python3-pip python3-venv -y
python -m venv venv
source venv/bin/activate
# Download model
pip install -U "huggingface_hub[cli]"
huggingface-cli download cognitivecomputations/dolphin-2.9.4-llama3.1-8b-gguf dolphin-2.9.4-llama3.1-8b-Q4_0.gguf --local-dir . --local-dir-use-symlinks False

# Run original downloaded model
QUANTIZE_METHOD="Q4_0"
./llama-cli -m dolphin-2.9.4-llama3.1-8b-${QUANTIZE_METHOD}.gguf \
  -p "Building a visually appealing website can be done in ten simple steps:" \
  -n 512 -t 64

# Re-quantize the model：on Graviton3
QUANTIZE_METHOD="Q4_0_8_8"
./llama-quantize --allow-requantize dolphin-2.9.4-llama3.1-8b-Q4_0.gguf dolphin-2.9.4-llama3.1-8b-${QUANTIZE_METHOD}.gguf ${QUANTIZE_METHOD}

# Re-quantize the model：on Graviton4
QUANTIZE_METHOD="Q4_0_4_8"
./llama-quantize --allow-requantize dolphin-2.9.4-llama3.1-8b-Q4_0.gguf dolphin-2.9.4-llama3.1-8b-${QUANTIZE_METHOD}.gguf ${QUANTIZE_METHOD}

# Run inference with re-quantized model:
./llama-cli -m dolphin-2.9.4-llama3.1-8b-${QUANTIZE_METHOD}.gguf \
  -p "Building a visually appealing website can be done in ten simple steps:" \
  -n 512 -t 64

 
# GPU 上运行 #######################################################################################
# # Run inference:
./llama-cli -m dolphin-2.9.4-llama3.1-8b-Q4_0.gguf \
  -p "Building a visually appealing website can be done in ten simple steps:" \
  -n 512 --n-gpu-layers 33 -b 1
  
# 监控GPU 资源利用率
nvidia-smi --query-gpu=utilization.gpu,utilization.memory,memory.total,memory.used --format=csv -l 1

