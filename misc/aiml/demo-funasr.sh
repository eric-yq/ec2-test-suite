apt install python3-pip python-is-python3
pip install torch==2.3.0 torchaudio==2.3.0
pip install funasr==0.8.8
pip install modelscope==1.10.0

export OMP_NUM_THREADS=16
# export DNNL_VERBOSE=1

# Enable the fast math GEMM kernels, to accelerate fp32 inference with bfloat16 gemm
export DNNL_DEFAULT_FPMATH_MODE=BF16

# Enable Linux Transparent Huge Page (THP) allocations,
# to reduce the tensor memory allocation latency
export THP_MEM_ALLOC_ENABLE=1

# Set LRU Cache capacity to cache the primitives and avoid redundant
# memory allocations
export LRU_CACHE_CAPACITY=1024

python
# >>>

import torch 
import torch.autograd.profiler as profiler 
import os 
import random 
import numpy as np 
from funasr.tasks.asr import ASRTaskParaformer as ASRTask 
from funasr.export.models import get_model 
from modelscope.hub.snapshot_download import snapshot_download

model_dir = snapshot_download('damo/speech_paraformer-large_asr_nat-zh-cn-16k-common-vocab8404-pytorch', cache_dir='./',revision=None)
#set the radom seed 0random.seed(0)np.random.seed(0)torch.random.manual_seed(0)
model, asr_train_args = ASRTask.build_model_from_file('damo/speech_paraformer-large_asr_nat-zh-cn-16k-common-vocab8404-pytorch/config.yaml','damo/speech_paraformer-large_asr_nat-zh-cn-16k-common-vocab8404-pytorch/model.pb' ,'damo/speech_paraformer-large_asr_nat-zh-cn-16k-common-vocab8404-pytorch/am.mvn' , 'cpu')
model = get_model(model, dict(feats_dim=560, onnx=False, model_name="model"))

batch = 64
seq_len = 93
dim = 560
speech = torch.randn((batch, seq_len, dim))
speech_lengths = torch.tensor([seq_len for _ in range(batch)], dtype=torch.int32) 
with torch.no_grad():
        with profiler.profile(with_stack=True, profile_memory=False, record_shapes=True) as prof:
            for _ in range(10):
                model(speech, speech_lengths)
        print(prof.key_averages(group_by_input_shape=True).table(sort_by='self_cpu_time_total', row_limit=200))

# >>> 退出
# c7g.4xlarge :
# FP32: Self CPU time total: 53.904s
# BF16: Self CPU time total: 36.335s
# c8g.4xlarge :
# FP32: Self CPU time total: 47.208s
# BF16: Self CPU time total: 29.981s


