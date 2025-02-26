#!/bin/bash

# 用法： bash qdrant-benchmark <IP地址>

source /tmp/temp-setting

## 需要进行 benchmark 的 SUT 主机
if [[ X${1} == X"" ]]; then
	HOST=""
else
    HOST="--host $1"
fi

## 执行 benchmark
cd /root/vector-db-benchmark/
rm -rf results/* nohup.out
eval "$(/root/miniconda3/bin/conda shell.bash hook)"
conda init
conda activate qdrant

##########################################################################################
# 启动测试: Search benchmark
# python3 -m run --engines XXX --datasets XXX
## --engines ： 在 experiments/configurations/qdrant-single-node.json 文件中搜索 "name"
#  qdrant-single-node-sq-rps.json:    "name": "qdrant-sq-rps-m-64-ef-512",
## --datasets： 在 datasets/datasets.json 文件中搜索 "name"
## 参考官方结果的数据集： https://qdrant.tech/benchmarks/#tested-datasets 
SETUP="qdrant-sq-rps-m-64-ef-512"
CONFIG_FILE=$(grep -l $SETUP /root/vector-db-benchmark/experiments/configurations/*.json)
sed -i.bak "/$SETUP/{n;n;s/30/600/}" $CONFIG_FILE
diff $CONFIG_FILE*
DATASET_SEARCH="dbpedia-openai-1M-1536-angular deep-image-96-angular gist-960-euclidean glove-100-angular"
for i in ${DATASET_SEARCH}
do
    echo "HOST=$HOST, TestPhase=Search, Setup=$SETUP, Dataset=$i"
    python3 -m run --engines $SETUP --datasets $i $HOST
done

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
DATASET_FILTER="random-100-match-kw-small-vocab-filters random-100-match-kw-small-vocab-no-filters arxiv-titles-384-angular-filters arxiv-titles-384-angular-no-filters random-geo-radius-100-angular-filters  random-geo-radius-100-angular-no-filters random-geo-radius-2048-angular-filters random-geo-radius-2048-angular-no-filters h-and-m-2048-angular-filters h-and-m-2048-angular-no-filters random-match-int-100-angular-filters  random-match-int-100-angular-no-filters random-match-int-2048-angular-filters random-match-int-2048-angular-no-filters random-match-keyword-100-angular-filters random-match-keyword-100-angular-no-filters random-match-keyword-2048-angular-filters random-match-keyword-2048-angular-no-filters random-range-100-angular-filters random-range-100-angular-no-filters random-range-2048-angular-filters random-range-2048-angular-no-filters"
for i in ${DATASET_FILTER}
do
    echo "HOST=$HOST, TestPhase=Search-and-Filter, Setup=$SETUP, Dataset=$i"
    python3 -m run --engines $SETUP --datasets $i $HOST
done

##########################################################################################
## 结果文件处理
RESULT_FILE_PATH="/root/vector-db-benchmark/results_$INSTANCE_TYPE"
mv /root/vector-db-benchmark/results $RESULT_FILE_PATH
# 合并数据
cd $RESULT_FILE_PATH
jq -s '.' *upload*.json > qdrant_benchmark_upload_$INSTANCE_TYPE.json
jq -s '.' *search*.json > qdrant_benchmark_search_$INSTANCE_TYPE.json
# qdrant_benchmark_search_m6i.2xlarge.json 
# qdrant_benchmark_upload_m6i.2xlarge.json
## 结果文件生成 csv 文件：upload 文件
echo "experiment,engine,dataset,parallel,batch_size,hnsw_config.m,hnsw_config.ef_construct,upload_time,total_time" > qdrant_benchmark_upload_$INSTANCE_TYPE.csv
jq -r '.[] | "\(.params.experiment),\(.params.engine),\(.params.dataset),\(.params.parallel),\(.params.batch_size),\(.params.hnsw_config.m),\(.params.hnsw_config.ef_construct),\(.results.upload_time),\(.results.total_time)"' qdrant_benchmark_upload_$INSTANCE_TYPE.json >> qdrant_benchmark_upload_$INSTANCE_TYPE.csv
## 结果文件生成 csv 文件：search 文件
echo "experiment,engine,dataset,parallel,hnsw_ef,oversampling,mean_precisions,rps,total_time,mean_time,p95_time,p99_time" > qdrant_benchmark_search_$INSTANCE_TYPE.csv
jq -r '.[] | "\(.params.experiment),\(.params.engine),\(.params.dataset),\(.params.parallel),\(.params.config.hnsw_ef),\(.params.config.quantization.oversampling),\(.results.mean_precisions),\(.results.rps),\(.results.total_time),\(.results.mean_time),\(.results.p95_time),\(.results.p99_time)"' qdrant_benchmark_search_$INSTANCE_TYPE.json >> qdrant_benchmark_search_$INSTANCE_TYPE.csv
cd ../
tar czf qdrant_benchmark_result_$INSTANCE_TYPE.tar.gz $RESULT_FILE_PATH/
cp qdrant_benchmark_result_$INSTANCE_TYPE.tar.gz /home/ec2-user/
