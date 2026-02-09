#!/bin/bash

## C8g.2xlarge, Ubuntu 22.04
# sudo su - root
cd /root/

## 1. 安装 Python，依赖包和 Docker
apt update
apt install -y python-is-python3 python3-pip python3-venv unzip
python -m venv venv
source venv/bin/activate
pip install --upgrade pymilvus openai requests langchain-huggingface huggingface_hub tqdm

apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=arm64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update
apt install -y docker-ce docker-ce-cli docker-compose containerd.io

systemctl start docker
systemctl enable docker
# systemctl status docker

## 2. 安装 Milvus
mkdir /root/milvus
cd /root/milvus
wget https://github.com/milvus-io/milvus/releases/download/v2.4.13/milvus-standalone-docker-compose.yml -O docker-compose.yml

docker-compose up -d
docker-compose ps

#（可选）安装 Web 管理工具
docker run -d -p 8000:3000 -e MILVUS_URL=$(hostname -i):19530 zilliz/attu:v2.4
echo "[Info] Use http://$(ec2-metadata --quiet --public-ipv4):8000 to login the Web UI."

## 3. 准备数据
cd /root/
wget https://github.com/milvus-io/milvus-docs/releases/download/v2.4.6-preview/milvus_docs_2.4.x_en.zip
unzip -q milvus_docs_2.4.x_en.zip -d milvus_docs

## 4. Build Llama.cpp
apt install -y git make cmake gcc g++ build-essential
cd /root/
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make GGML_NO_LLAMAFILE=1 -j$(nproc)

./llama-cli -h

## 5. Download and Requantize LLM model weights
cd /root/
huggingface-cli download cognitivecomputations/dolphin-2.9.4-llama3.1-8b-gguf dolphin-2.9.4-llama3.1-8b-Q4_0.gguf --local-dir . --local-dir-use-symlinks False 

FORMAT="Q4_0_4_8" # Q4_0_4_8 for Graviton4, Q4_0_8_8 for Graviton3
/root/llama.cpp/llama-quantize --allow-requantize dolphin-2.9.4-llama3.1-8b-Q4_0.gguf dolphin-2.9.4-llama3.1-8b-$FORMAT.gguf $FORMAT

ls -l dolphin-2.9.4-llama3.1-8b-*

## 6. Start LLM server
nohup /root/llama.cpp/llama-server -m /root/dolphin-2.9.4-llama3.1-8b-$FORMAT.gguf -n 2048 -c 65536 --port 8080 &

