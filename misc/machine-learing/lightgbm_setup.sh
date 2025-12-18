 #!/bin/bash

# Amazon Linux 2023

yum group install -yq "Development Tools"
yum install -yq python3-pip htop git
pip3 install dool

# 安装conda
cd /root
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(arch).sh \
  -O Miniconda3-latest-Linux-$(arch).sh
bash Miniconda3-latest-Linux-$(arch).sh -b   
echo "PATH=/root/miniconda3/bin:$PATH" >> /root/.bashrc
source ~/.bashrc

# https://microsoft.github.io/lightgbm-benchmark/run/install/
# 创建 lightgbm benchmark 环境 3.8
conda create --name lgbm python=3.8 -y
conda activate lgbm
git clone https://github.com/microsoft/lightgbm-benchmark.git
cd lightgbm-benchmark/
yum install -yq openmpi-devel
cp -r /usr/include/openmpi-$(arch)/* /root/miniconda3/envs/lgbm/include/python3.8/
export MPICC=/usr/lib64/openmpi/bin/mpicc
export MPI_DIR=/usr/lib64/openmpi
python -m pip install -r requirements.txt
pip install -U scikit-learn

# 生成数据
python src/scripts/data_processing/generate_data/generate.py \
    --train_samples 30000 \
    --test_samples 3000 \
    --inferencing_samples 30000 \
    --n_features 4000 \
    --n_informative 400 \
    --random_state 5 \
    --output_train ./data/synthetic/train/ \
    --output_test ./data/synthetic/test/ \
    --output_inference ./data/synthetic/inference/ \
    --type regression \
    --external_header ./data/synthetic/headers/

pip install 'numpy==1.23.5'

# 训练：Run training on synthetic data
python src/scripts/training/lightgbm_python/train.py \
    --train ./data/synthetic/train/ \
    --test ./data/synthetic/test/ \
    --export_model ./data/models/synthetic-100trees-4000cols/ \
    --objective regression \
    --boosting_type gbdt \
    --tree_learner serial \
    --metric rmse \
    --num_trees 100 \
    --num_leaves 100 \
    --min_data_in_leaf 400 \
    --learning_rate 0.3 \
    --max_bin 16 \
    --feature_fraction 0.15 \
    --device_type cpu