#!/bin/bash
# Ubuntu 22.04 and Amazon Linux 2023

sudo su - root
apt install -y build-* htop dstat
yum groupinstall -y "Development Tools"

## Install conda
cd /root/
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(arch).sh
bash Miniconda3-latest-Linux-$(arch).sh -b -p /root/miniconda3/
eval "$(/root/miniconda3/bin/conda shell.bash hook)"
conda init
source /root/.bashrc

## Create python env
testname="dclm"
conda create -y -q -n ${testname} python=3.11
conda activate $testname

## Install torch and open_lm
pip install torch==2.3.1
pip install git+https://github.com/mlfoundations/open_lm.git

## hf_model_id
# apple/DCLM-7B
# TRI-ML/DCLM-1B

## Create a test script to invoke models.
cat << EOF > test-dclm.py
from open_lm.hf import *
from transformers import AutoTokenizer, AutoModelForCausalLM
import time 
import sys

if len(sys.argv) != 2:
    print("用法: python script.py <hf_model_id>")
    sys.exit(1)
param = sys.argv[1]
# print(f"The parameter: {param}")

# Load model
model_id=param
tokenizer = AutoTokenizer.from_pretrained(model_id)
model = AutoModelForCausalLM.from_pretrained(model_id)

# coded
inputs = tokenizer(["Machine learning is"], return_tensors="pt")

# set the parameters:
gen_kwargs = {
    "max_new_tokens": 50,
    "top_p": 0.8,
    "temperature": 0.8,
    "do_sample": True,
    "repetition_penalty": 1.1
}

# generate text
start_time = time.time()
output = model.generate(inputs['input_ids'], **gen_kwargs)
end_time = time.time()

# decode:
decoded_output = tokenizer.decode(output[0].tolist(), skip_special_tokens=True)
num_tokens_generated = output.shape[1] - inputs['input_ids'].shape[1]
generation_time = end_time - start_time

# caculate tokens_per_second: 
tokens_per_second = num_tokens_generated / generation_time if generation_time > 0 else 0

# print the result
print(f"Generated Text: {decoded_output}")
print(f"Generated number of tokens: {num_tokens_generated}")
print(f"Duration: {generation_time:.2f} 秒")
print(f"Tokens-generated per second: {tokens_per_second:.2f} tokens/秒")
EOF

# python test-dclm.py apple/DCLM-7B
python test-dclm.py TRI-ML/DCLM-1B


############ Only for performance profiling:
## Install perf
sudo apt install -y linux-tools-common linux-tools-generic linux-tools-$(uname -r)
yum install perf

## Install aperf
wget https://github.com/aws/aperf/releases/download/v0.1.12-alpha/aperf-v0.1.12-alpha-$(arch).tar.gz -O  aperf-v0.1.12-alpha.tar.gz 
tar zxf aperf-v0.1.12-alpha.tar.gz --strip-components 1 -C /usr/local/bin/
aperf -V

# enable PMU access
echo 0 | sudo tee /proc/sys/kernel/perf_event_paranoid
# APerf has to open more than the default limit of files.
ulimit -n 65536

INS_TYPE=$(ec2-metadata --quiet --instance-type)
# sually aperf would be run in another terminal. 
# For illustration purposes it is send to the background here
aperf record --run-name dclm_$INS_TYPE --period 30 &

python test-dclm.py TRI-ML/DCLM-1B

## Generate APerf compare report between r7g and r8g.
aperf report --run dclm_r7g.2xlarge --run dclm_r8g.2xlarge
