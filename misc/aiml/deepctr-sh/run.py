import onnxruntime as ort
import random
savename = 'converted_onnx_model/mtl_model_240929_0343.onnx'
sess_options = ort.SessionOptions()
sess = ort.InferenceSession(f"{savename}", providers=["CPUExecutionProvider"])

from tf_perf_utils import *
from datetime import datetime
TIMESTR = datetime.now().strftime("%y%m%d_%H%M")
@concurrency_decorator([2, 2, 4, 8, 16, 32, 48, 64])
# @concurrency_decorator([1, 99, 96])
# @concurrency_decorator([2, 4])
@timer_decorator
def call_local_inf():
    num_samples = random.randint(90,110)
    reshaped_dict = gen_emb_as_input(num_samples)
    func_res = sess.run(['p1', 'p2'], reshaped_dict)
    return num_samples, func_res
timed_results = call_local_inf()
print(timed_results)
import json
with open(f'output-detail-{TIMESTR}.json', 'w') as f:
    json.dump(timed_results, f, indent=2, allow_nan=False)
import numpy as np
import pandas as pd
accums = {}
stats = {}
for k in timed_results.keys():
    accums[k] = [v[0] for v in timed_results[k]]
    tot_req = sum([v[1] for v in timed_results[k]])
    flatten_accum = accums[k]*tot_req
    stats[k] = [tot_req, np.mean(flatten_accum), np.percentile(flatten_accum, 50), np.percentile(flatten_accum, 95), np.percentile(flatten_accum, 99)]

df = pd.DataFrame.from_dict(stats, orient='index', columns=['numreq', 'mean', 'p50', 'p95', 'p99'])
df = df.reset_index().rename(columns={'index': 'concurrency'})
df.to_csv(f'output-metrics-{TIMESTR}.csv', index = False)
