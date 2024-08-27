#!/bin/bash

# On Amazon Linux 2023
sudo su - root

##########################################################################################
# 安装服务端
## 安装 docker 和 docker-compose
cd /root/
yum install -y docker git htop python3.11
systemctl start docker
VER="v2.29.2"
ARCH=$(arch)
curl -SL https://github.com/docker/compose/releases/download/$VER/docker-compose-linux-${ARCH} -o /usr/bin/docker-compose
chmod +x /usr/bin/docker-compose

## 启动 qdrant 服务
git clone https://github.com/qdrant/vector-db-benchmark.git
ENGINE_CONFIG_NAME="qdrant-single-node"
cd /root/vector-db-benchmark/engine/servers/$ENGINE_CONFIG_NAME
docker-compose up -d
## 查看状态
docker-compose ps


##########################################################################################
# 安装客户端
## Install conda
cd /root/
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(arch).sh
bash Miniconda3-latest-Linux-$(arch).sh -b -p /root/miniconda3/
eval "$(/root/miniconda3/bin/conda shell.bash hook)"
conda init
source /root/.bashrc
## Create python env
testname="qdrant"
conda create -y -q -n ${testname} python=3.11

## 安装客户端
conda activate $testname
pip install poetry
cd /root/vector-db-benchmark/
poetry install

if [[ $(arch) == "aarch64" ]]; then
	echo "Arch is $(arch), build hdf5 and install h5py..."
    install_h5py_aarch64
else
    echo "Arch is $(arch), h5py will install automatically."
fi

##########################################################################################
# 启动测试
# python3 -m run --engines XXX --datasets XXX
## --engines ： 在 experiments/configurations/qdrant-single-node.json 文件中搜索 "name"
#  qdrant-single-node-sq-rps.json:    "name": "qdrant-sq-rps-m-64-ef-512",
## --datasets： 在 datasets/datasets.json 文件中搜索 "name"
## 采用4个数据集： https://qdrant.tech/benchmarks/#tested-datasets 
#  dbpedia-openai-1M-1536-angular
#  deep-image-96-angular
#  gist-960-euclidean
#  glove-100-angular

cat << EOF > test123.sh
python3 -m run --engines qdrant-sq-rps-m-64-ef-512 --datasets dbpedia-openai-1M-1536-angular
python3 -m run --engines qdrant-sq-rps-m-64-ef-512 --datasets deep-image-96-angular
python3 -m run --engines qdrant-sq-rps-m-64-ef-512 --datasets gist-960-euclidean
python3 -m run --engines qdrant-sq-rps-m-64-ef-512 --datasets glove-100-angular
EOF

nohup bash test123.sh &



install_h5py_aarch64 {
# build hdf5
    yum groupinstall -y -q "Development Tools"
    cd ~
	wget https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5-1_10_7.tar.gz
	tar zxf hdf5-1_10_7.tar.gz
	cd hdf5-hdf5-1_10_7/
	./configure --enable-cxx --prefix=/usr/local/hdf5
	make -j$(nproc)
	make install 
# install h5py
	cd ~
	HDF5_DIR=/usr/local/hdf5 pip install --no-binary=h5py h5py
}



### 将 https://qdrant.tech/benchmarks/results-1-100-thread-2024-06-15.json 对应的 json文件中的格式：
#   {
#     "engine_name": "qdrant",
#     "setup_name": "qdrant-sq-rps-m-64-ef-512",
#     "dataset_name": "dbpedia-openai-1M-1536-angular",
#     "upload_time": 211.02451519703027,
#     "total_upload_time": 1466.1785857389914,
#     "p95_time": 0.003128117803134956,
#     "rps": 319.1132749085913,
#     "parallel": 1,
#     "p99_time": 0.003539099645131501,
#     "mean_time": 0.0025649284036204337,
#     "mean_precisions": 0.9915200000000001,
#     "engine_params": {
#       "hnsw_ef": 64,
#       "quantization": {
#         "rescore": true,
#         "oversampling": 2
#       }
#     }
#   }
### 通过 jq 命令将这个文件转换为 csv 文件：
# jq -r '.[] | "\(.engine_name), \(.setup_name), \(.dataset_name), \(.upload_time), \(.total_upload_time), \(.parallel), \(.engine_params.hnsw_ef), \(.engine_params.quantization.oversampling), \(.rps), \(.mean_precisions), \(.mean_time), \(.p95_time), \(.p99_time)"' results-1-100-thread-2024-06-15.json > results-1-100-thread-2024-06-15-new.csv





