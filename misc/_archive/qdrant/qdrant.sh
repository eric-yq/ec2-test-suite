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
# 客户端操作：
## 安装 conda
cd /root/
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(arch).sh
bash Miniconda3-latest-Linux-$(arch).sh -b -p /root/miniconda3/
eval "$(/root/miniconda3/bin/conda shell.bash hook)"
conda init
source /root/.bashrc

## 创建 python 环境
testname="qdrant"
conda create -y -q -n ${testname} python=3.11

## 安装客户端软件
conda activate $testname
pip install poetry

## 在 aarch64 实例构建 h5p5
install_h5py_aarch64 {
# build hdf5
    yum groupinstall -y "Development Tools"
    cd /root/
	wget https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5-1_10_7.tar.gz
	tar zxf hdf5-1_10_7.tar.gz
	cd hdf5-hdf5-1_10_7/
	./configure --enable-cxx --prefix=/usr/local/hdf5
	make -j $(nproc)
	make install 
# install h5py
	HDF5_DIR=/usr/local/hdf5 pip install --no-binary=h5py h5py
}
if [[ $(arch) == "aarch64" ]]; then
	echo "Arch is $(arch), build hdf5 and install h5py..."
    install_h5py_aarch64
else
    echo "Arch is $(arch), h5py will install automatically."
fi

cd /root/vector-db-benchmark/
poetry install

## 需要进行 benchmark 的 SUT 主机
if [[ X${1} == X"" ]]; then
	HOST=""
else
    HOST="--host $1"
fi

sed -i '/qdrant-sq-rps-m-64-ef-512/{n;n;s/30/60/}' a.json


##########################################################################################
# 启动测试: Search benchmark
# python3 -m run --engines XXX --datasets XXX
## --engines ： 在 experiments/configurations/qdrant-single-node.json 文件中搜索 "name"
#  qdrant-single-node-sq-rps.json:    "name": "qdrant-sq-rps-m-64-ef-512",
## --datasets： 在 datasets/datasets.json 文件中搜索 "name"
## 参考官方结果的数据集： https://qdrant.tech/benchmarks/#tested-datasets 
cd /root/vector-db-benchmark/
SETUP="qdrant-sq-rps-m-64-ef-512"
CONFIG_FILE=$(grep -l $SETUP /root/vector-db-benchmark/experiments/configurations/*.json)
sed -i.bak "/$SETUP/{n;n;s/30/600/}" $CONFIG_FILE
diff $CONFIG_FILE*
DATASET_SEARCH="dbpedia-openai-1M-1536-angular deep-image-96-angular gist-960-euclidean glove-100-angular"
cat << EOF > test-search.sh
for i in $DATASET_SEARCH
do
    python3 -m run --engines $SETUP --datasets $i $HOST
done
EOF

##########################################################################################
# 启动测试: Filter search benchmark
# python3 -m run --engines XXX --datasets XXX
## --engines ： 在 experiments/configurations/qdrant-single-node.json 文件中搜索 "name"
#  qdrant-single-node-sq-rps.json:    "name": "qdrant-m-16-ef-128",
## --datasets： 在 datasets/datasets.json 文件中搜索 "name"
## 参考官方结果的数据集： https://qdrant.tech/benchmarks/filter-result-2023-02-03.json
cd /root/vector-db-benchmark/
SETUP="qdrant-m-16-ef-128"
CONFIG_FILE=$(grep -l $SETUP /root/vector-db-benchmark/experiments/configurations/*.json)
sed -i.bak "/$SETUP/{n;n;s/30/600/}" $CONFIG_FILE
diff $CONFIG_FILE*
DATASET_FILTER="100-kw-small-vocab-filters  100-kw-small-vocab-no-filters  arxiv-titles-384-filters  arxiv-titles-384-no-filters  geo-radius-100-filters  geo-radius-100-no-filters  geo-radius-2048-filters  geo-radius-2048-no-filters  h-and-m-2048-filters  h-and-m-2048-no-filters  int-100-filters  int-100-no-filters  int-2048-filters  int-2048-no-filters  keyword-100-filters  keyword-100-no-filters  keyword-2048-filters  keyword-2048-no-filters  range-100-filters  range-100-no-filters  range-2048-filters  range-2048-no-filters"
cat << EOF > test-filter.sh
for i in $DATASET_FILTER
do
    python3 -m run --engines $SETUP --datasets $i $HOST
done
EOF

## 修改 upload 操作超时时间
# sed -i.bak "66a\            timeout=7200" /root/vector-db-benchmark/engine/clients/qdrant/upload.py
## 执行 benchmark
rm -rf results/* nohup.out
bash test-search.sh
bash test-filter.sh

##########################################################################################
## 结果文件处理
INS_TYPE=$(ec2-metadata --quiet --instance-type)
RESULT_FILE_PATH="/root/vector-db-benchmark/results_$INS_TYPE"
mkdir -p $RESULT_FILE_PATH
mv /root/vector-db-benchmark/*.json $RESULT_FILE_PATH/
# 合并数据
cd $RESULT_FILE_PATH/
INS_TYPE=$(ec2-metadata --quiet --instance-type)
jq -s '.' *upload*.json > qdrant_benchmark_upload_$INS_TYPE.json
jq -s '.' *search*.json > qdrant_benchmark_search_$INS_TYPE.json
# qdrant_benchmark_search_m6i.2xlarge.json 
# qdrant_benchmark_upload_m6i.2xlarge.json
## 结果文件生成 csv 文件：upload 文件
echo "experiment,engine,dataset,parallel,batch_size,hnsw_config.m,hnsw_config.ef_construct,upload_time,total_time" > qdrant_benchmark_upload_$INS_TYPE.csv
jq -r '.[] | "\(.params.experiment),\(.params.engine),\(.params.dataset),\(.params.parallel),\(.params.batch_size),\(.params.hnsw_config.m),\(.params.hnsw_config.ef_construct),\(.results.upload_time),\(.results.total_time)"' qdrant_benchmark_upload_$INS_TYPE.json >> qdrant_benchmark_upload_$INS_TYPE.csv
## 结果文件生成 csv 文件：search 文件
INS_TYPE=$(ec2-metadata --quiet --instance-type)
echo "experiment,engine,dataset,parallel,hnsw_ef,oversampling,mean_precisions,rps,total_time,mean_time,p95_time,p99_time" > qdrant_benchmark_search_$INS_TYPE.csv
jq -r '.[] | "\(.params.experiment),\(.params.engine),\(.params.dataset),\(.params.parallel),\(.params.config.hnsw_ef),\(.params.config.quantization.oversampling),\(.results.mean_precisions),\(.results.rps),\(.results.total_time),\(.results.mean_time),\(.results.p95_time),\(.results.p99_time)"' qdrant_benchmark_search_$INS_TYPE.json >> qdrant_benchmark_search_$INS_TYPE.csv
cd ../
tar czf qdrant_benchmark_result_$INS_TYPE.tar.gz $RESULT_FILE_PATH/
cp qdrant_benchmark_result_$INS_TYPE.tar.gz /home/ec2-user/

## upload 文件
#   {
#     "params": {
#       "experiment": "qdrant-sq-rps-m-64-ef-512",
#       "engine": "qdrant",
#       "dataset": "dbpedia-openai-1M-1536-angular",
#       "parallel": 16,
#       "batch_size": 1024,
#       "optimizers_config": {
#         "max_segment_size": 1000000,
#         "memmap_threshold": 10000000,
#         "default_segment_number": 2
#       },
#       "hnsw_config": {
#         "m": 64,
#         "ef_construct": 512
#       },
#       "quantization_config": {
#         "scalar": {
#           "type": "int8",
#           "quantile": 0.99,
#           "always_ram": true
#         }
#       }
#     },
#     "results": {
#       "post_upload": {},
#       "upload_time": 320.67010107799433,
#       "total_time": 1343.5359594210022
#     }
#   }
#
## search 文件
#   {
#     "params": {
#       "dataset": "dbpedia-openai-1M-1536-angular",
#       "experiment": "qdrant-sq-rps-m-64-ef-512",
#       "engine": "qdrant",
#       "parallel": 1,
#       "config": {
#         "hnsw_ef": 64,
#         "quantization": {
#           "rescore": true,
#           "oversampling": 1.0
#         }
#       }
#     },
#     "results": {
#       "total_time": 14.071015573994373,
#       "mean_time": 0.002298591131120338,
#       "mean_precisions": 0.9929,
#       "std_time": 0.0002850996156008218,
#       "min_time": 0.0015700549993198365,
#       "max_time": 0.008849541991367005,
#       "rps": 355.3403785040825,
#       "p95_time": 0.0027295801570289767,
#       "p99_time": 0.0028827918137540112
#     }
#   }




### 附录：https://qdrant.tech/benchmarks/results-1-100-thread-2024-06-15.json 中的格式
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
#
### 通过 jq 命令将这个文件转换为 csv 文件：
# jq -r '.[] | "\(.engine_name), \(.setup_name), \(.dataset_name), \(.upload_time), \(.total_upload_time), \(.parallel), \(.engine_params.hnsw_ef), \(.engine_params.quantization.oversampling), \(.rps), \(.mean_precisions), \(.mean_time), \(.p95_time), \(.p99_time)"' results-1-100-thread-2024-06-15.json > results-1-100-thread-2024-06-15-new.csv


