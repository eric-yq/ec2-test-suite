#!/bin/bash

# 用法： bash qdrant-benchmark <IP地址> <EC2规格>


## 需要进行 benchmark 的 SUT 主机
if [[ X${1} == X"" ]]; then
	HOST=""
else
    HOST="--host $1"
fi

INS_TYPE=${2}

##########################################################################################
# 启动测试: Search benchmark
# python3 -m run --engines XXX --datasets XXX
## --engines ： 在 experiments/configurations/qdrant-single-node.json 文件中搜索 "name"
#  qdrant-single-node-sq-rps.json:    "name": "qdrant-sq-rps-m-64-ef-512",
## --datasets： 在 datasets/datasets.json 文件中搜索 "name"
## 参考官方结果的数据集： https://qdrant.tech/benchmarks/#tested-datasets 
cd /root/vector-db-benchmark/
DATASET_SEARCH="dbpedia-openai-1M-1536-angular deep-image-96-angular gist-960-euclidean glove-100-angular"
cat << EOF > test-search.sh
for i in $DATASET_SEARCH
do
    python3 -m run --engines qdrant-sq-rps-m-64-ef-512 --datasets $i $HOST
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
DATASET_FILTER="100-kw-small-vocab-filters  100-kw-small-vocab-no-filters  arxiv-titles-384-filters  arxiv-titles-384-no-filters  geo-radius-100-filters  geo-radius-100-no-filters  geo-radius-2048-filters  geo-radius-2048-no-filters  h-and-m-2048-filters  h-and-m-2048-no-filters  int-100-filters  int-100-no-filters  int-2048-filters  int-2048-no-filters  keyword-100-filters  keyword-100-no-filters  keyword-2048-filters  keyword-2048-no-filters  range-100-filters  range-100-no-filters  range-2048-filters  range-2048-no-filters"
cat << EOF > test-filter.sh
for i in $DATASET_FILTER
do
    python3 -m run --engines  qdrant-m-16-ef-128 --datasets $i $HOST
done
EOF

## 修改 upload 操作超时时间
# sed -i.bak "66a\            timeout=1800" /root/vector-db-benchmark/engine/clients/qdrant/upload.py

## 执行 benchmark
rm -rf results/* nohup.out
bash test-search.sh
bash test-filter.sh

##########################################################################################
## 结果文件处理
RESULT_FILE_PATH="/root/vector-db-benchmark/results_$INS_TYPE"
mkdir -p $RESULT_FILE_PATH
mv /root/vector-db-benchmark/*.json $RESULT_FILE_PATH/
# 合并数据
cd $RESULT_FILE_PATH/
jq -s '.' *upload*.json > qdrant_benchmark_upload_$INS_TYPE.json
jq -s '.' *search*.json > qdrant_benchmark_search_$INS_TYPE.json
# qdrant_benchmark_search_m6i.2xlarge.json 
# qdrant_benchmark_upload_m6i.2xlarge.json
## 结果文件生成 csv 文件：upload 文件
echo "experiment,engine,dataset,parallel,batch_size,hnsw_config.m,hnsw_config.ef_construct,upload_time,total_time" > qdrant_benchmark_upload_$INS_TYPE.csv
jq -r '.[] | "\(.params.experiment),\(.params.engine),\(.params.dataset),\(.params.parallel),\(.params.batch_size),\(.params.hnsw_config.m),\(.params.hnsw_config.ef_construct),\(.results.upload_time),\(.results.total_time)"' qdrant_benchmark_upload_$INS_TYPE.json >> qdrant_benchmark_upload_$INS_TYPE.csv
## 结果文件生成 csv 文件：search 文件
echo "experiment,engine,dataset,parallel,hnsw_ef,oversampling,mean_precisions,rps,total_time,mean_time,p95_time,p99_time" > qdrant_benchmark_search_$INS_TYPE.csv
jq -r '.[] | "\(.params.experiment),\(.params.engine),\(.params.dataset),\(.params.parallel),\(.params.config.hnsw_ef),\(.params.config.quantization.oversampling),\(.results.mean_precisions),\(.results.rps),\(.results.total_time),\(.results.mean_time),\(.results.p95_time),\(.results.p99_time)"' qdrant_benchmark_search_$INS_TYPE.json >> qdrant_benchmark_search_$INS_TYPE.csv
cd ../
tar czf qdrant_benchmark_result_$INS_TYPE.tar.gz $RESULT_FILE_PATH/
cp qdrant_benchmark_result_$INS_TYPE.tar.gz /home/ec2-user/
