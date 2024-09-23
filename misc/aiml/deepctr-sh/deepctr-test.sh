#!/bin/bash

## Amazon Linux 2023

yum install -y git

# 安装 conda
cd /root/
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(arch).sh
bash Miniconda3-latest-Linux-$(arch).sh -b -p /root/miniconda3/
eval "$(/root/miniconda3/bin/conda shell.bash hook)"
conda init
source /root/.bashrc

# 创建Python3.9运行环境 deepctr
testname="deepctr"
conda create -y -q -n ${testname} python=3.9
conda activate $testname

# 安装依赖包
pip install onnxruntime==1.17.1
pip install numpy==1.26.4 # deepctr需要numpy 1.x

# 安装 DeepCTR
git clone https://github.com/shenweichen/DeepCTR.git
cd DeepCTR
python setup.py install

# 
cat << EOF > test.py
import onnxruntime as ort
import numpy as np
import time
sess = ort.InferenceSession("mtl_model3.onnx")
sample_input = {
    'user': np.array([[0]], dtype=np.int32),
    'gender': np.array([[0]], dtype=np.int32),
    'item_id': np.array([[1]], dtype=np.int32),
    'cate_id': np.array([[1]], dtype=np.int32),
    'pay_score': np.array([[0.1]], dtype=np.float32),
    'hist_item_id': np.array([[1, 2, 3, 3, 0, 0, 0, 0]], dtype=np.int32),
    'hist_cate_id': np.array([[1, 2, 2, 16, 0, 0, 0, 0]], dtype=np.int32),
    'seq_length': np.array([[3]], dtype=np.int32),
    'hist2_item_id': np.array([[1, 2, 3, 2, 1, 3, 1, 0]], dtype=np.int32),
    'hist2_cate_id': np.array([[1, 2, 1, 2, 1, 1, 1, 0]], dtype=np.int32),
    'seq2_length': np.array([[7]], dtype=np.int32)
}

st = time.perf_counter()
results = []
for i in range(100):
    print(i, end=' ')
    results_ort = sess.run(['ctcvr', 'ctr'], sample_input)
    results.append(results_ort)
edt = time.perf_counter()-st
print('time consumption: ', edt)
print('results: ', results)
EOF

# get the model:
cp /home/ec2-user/mtl_model3.onnx .

python 1.py




