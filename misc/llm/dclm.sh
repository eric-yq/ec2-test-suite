#!/bin/bash
# Ubuntu 22.04

sudo su - root
apt install -y build-* htop dstat nload

## 安装 conda（下面这些需要基于特定版本 python 进行测试。）
cd /root/
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(arch).sh
bash Miniconda3-latest-Linux-$(arch).sh -b -p /root/miniconda3/
eval "$(/root/miniconda3/bin/conda shell.bash hook)"
conda init
source /root/.bashrc

## 创建 python 虚拟环境
testname="dclm"
conda create -y -q -n ${testname} python=3.11
conda activate $testname

## 安装 open_lm
pip install torch
pip install git+https://github.com/mlfoundations/open_lm.git

## hf_model_id
# apple/DCLM-7B
# TRI-ML/DCLM-1B

## 使用
cat << EOF > test-dclm.py
from open_lm.hf import *
from transformers import AutoTokenizer, AutoModelForCausalLM
import time  # 导入时间模块
import sys

# 检查参数数量
if len(sys.argv) != 2:
    print("用法: python script.py <hf_model_id>")
    sys.exit(1)

# 获取参数
param = sys.argv[1]
# print(f"传入的参数是: {param}")

# 加载模型和分词器
model_id=param
tokenizer = AutoTokenizer.from_pretrained(model_id)
model = AutoModelForCausalLM.from_pretrained(model_id)

# 编码输入文本
inputs = tokenizer(["Machine learning is"], return_tensors="pt")

# 设置生成参数
gen_kwargs = {
    "max_new_tokens": 512,
    "top_p": 0.8,
    "temperature": 0.8,
    "do_sample": True,
    "repetition_penalty": 1.1
}

# 生成文本并计时
start_time = time.time()
output = model.generate(inputs['input_ids'], **gen_kwargs)
end_time = time.time()

# 解码生成的标记，计算生成的 token 数量和使用的时间
decoded_output = tokenizer.decode(output[0].tolist(), skip_special_tokens=True)
num_tokens_generated = output.shape[1] - inputs['input_ids'].shape[1]
generation_time = end_time - start_time

# 计算每秒生成的 token 数量
tokens_per_second = num_tokens_generated / generation_time if generation_time > 0 else 0

# 打印结果
print(f"生成的文本: {decoded_output}")
print(f"生成的 token 数量: {num_tokens_generated}")
print(f"生成时间: {generation_time:.2f} 秒")
print(f"每秒生成的 token 数量: {tokens_per_second:.2f} tokens/秒")
EOF



python test.py