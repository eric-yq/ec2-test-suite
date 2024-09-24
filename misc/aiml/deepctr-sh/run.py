import onnxruntime as ort
savename = 'converted_onnx_model/mtl_model_240920_0823.onnx'
sess_options = ort.SessionOptions()
sess = ort.InferenceSession(f"{savename}", providers=["CPUExecutionProvider"])

from tf_perf_utils import *
from datetime import datetime
TIMESTR = datetime.now().strftime("%y%m%d_%H%M")
@concurrency_decorator([2, 2, 4, 8, 12, 16, 24, 32, 40, 48, 56, 64, 80, 96])
# @concurrency_decorator([1, 99, 96])
# @concurrency_decorator([2, 4])
@timer_decorator
def call_local_inf():
    num_samples = 1
    feature_dict = generate_random_data(num_samples)
    reshaped_dict = reshape_single_element_arrays(feature_dict)
    func_res = sess.run(['p1', 'p2'], reshaped_dict)
    return func_res
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
    stats[k] = [np.mean(accums[k]), np.percentile(accums[k], 50), np.percentile(accums[k], 95), np.percentile(accums[k], 99)]

df = pd.DataFrame.from_dict(stats, orient='index', columns=['mean', 'p50', 'p95', 'p99'])
df = df.reset_index().rename(columns={'index': 'concurrency'})
df.to_csv(f'output-metrics-{TIMESTR}.csv', index = False)
