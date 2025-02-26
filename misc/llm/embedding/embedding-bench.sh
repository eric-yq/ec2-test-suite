#!/bin/bash

# On Amazon Linux 2023
sudo su - root
yum groupinstall -y "Development Tools"

# Install conda
cd /root/
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(arch).sh
bash Miniconda3-latest-Linux-$(arch).sh -b -p /root/miniconda3/
eval "$(/root/miniconda3/bin/conda shell.bash hook)"
conda init
source /root/.bashrc

## Create python env
testname="mteb"
conda create -y -q -n ${testname} python=3.12
conda activate $testname

# Install mteb: https://github.com/embeddings-benchmark/mteb
pip install mteb dool

# Set env settings
export DNNL_DEFAULT_FPMATH_MODE=BF16
export THP_MEM_ALLOC_ENABLE=1

# Start single task:
# MODEL="sentence-transformers/all-MiniLM-L12-v2"
# MODEL="BAAI/bge-large-en-v1.5"
# MODEL="sentence-transformers/all-mpnet-base-v2"
# TASKS="Banking77Classification"
# mteb run -m $MODEL -t $TASKS --verbosity 3 --overwrite

##########################################################################
# 1. Start benchmark with models: BAAI/bge-large-en-v1.5
MODEL="BAAI/bge-large-en-v1.5"
# 1.1 
BENCH="MTEB(eng, classic)"
echo "[Info] Star to run benchmark: $MODEL, $BENCH ......"
mteb run --benchmark "$BENCH" --model $MODEL --overwrite
# 1.2
BENCH="MTEB(code)"
echo "[Info] Star to run benchmark: $MODEL, $BENCH ."
mteb run --benchmark "$BENCH" --model $MODEL --overwrite

sleep 600

# 2. Start benchmark with models: sentence-transformers/all-MiniLM-L12-v2
MODEL="sentence-transformers/all-MiniLM-L12-v2"
# 2.1
BENCH="MTEB(eng, classic)"
echo "[Info] Star to run benchmark: $MODEL, $BENCH ......"
mteb run --benchmark "$BENCH" --model $MODEL --overwrite
# 2.2
BENCH="MTEB(code)"
echo "[Info] Star to run benchmark: $MODEL, $BENCH ."
mteb run --benchmark "$BENCH" --model $MODEL --overwrite

echo "[Info] Complete all tests."


## https://github.com/embeddings-benchmark/mteb/blob/0c7c216b1c9ccf36c8fb5575f6344c92ffb727d3/docs/benchmarks.md
## https://github.com/embeddings-benchmark/mteb/blob/0c7c216b1c9ccf36c8fb5575f6344c92ffb727d3/mteb/benchmarks/benchmarks.py
# MTEB_EN = Benchmark(
#     name="MTEB(eng, beta)",
#     tasks=get_tasks(
# 1    name="MTEB(eng, classic)",
#     name="MTEB(rus)",
#     name="MTEB(Retrieval w/Instructions)",
#     name="MTEB(law)",  # This benchmark is likely in the need of an update
#     name="MTEB(Scandinavian)",
#     name="MTEB(fra)",
#     name="MTEB(deu)",
#     name="MTEB(kor)",
#     name="MTEB(pol)",
# 2    name="MTEB(code)",
#     name="MTEB(Multilingual, beta)",
#     name="MTEB(jpn)",
#     name="MTEB(Indic, beta)",
#     name="MTEB(Europe, beta)",