import os
import numpy as np

UID_SIZE = 100000
IID_SIZE = 10000
FEAT_SIZE = 64

NUM_FEATS = 120
FEAT_NAMES = [f'feat{i}' for i in range(NUM_FEATS)]

SEQ_MAX_LENS = [200,100,50,50]
SEQ_SNAPSHOT_FEATS = ['item_id'] + FEAT_NAMES[0:4]

def generate_random_data(num_samples):

    def _generate_hist_data(num_samples, max_length, seq_lengths, value_range):
        hist_data = np.zeros((num_samples, max_length), dtype=np.int32)
        for i in range(num_samples):
            length = seq_lengths[i]
            hist_data[i, :length] = np.random.randint(1, value_range + 1, length)
        return hist_data
    
    feats = {
        'user': np.arange(1, num_samples+1, dtype=np.int32),
        'item_id': np.random.randint(1, IID_SIZE, num_samples, dtype=np.int32),
        'score': np.random.uniform(0.01, 1, num_samples).astype(np.float32),
        'amount': np.random.uniform(0.01, 99.99, num_samples).astype(np.float32),
    }

    for fname in FEAT_NAMES:
        feats[fname] = np.random.randint(1, FEAT_SIZE, num_samples, dtype=np.int32)

    for i in range(0, len(SEQ_MAX_LENS)):
        feats.update(
            {f'seq{i}_length': np.random.randint(SEQ_MAX_LENS[i]//2, SEQ_MAX_LENS[i]+1, num_samples, dtype=np.int32)}
        )

        for semb_base in SEQ_SNAPSHOT_FEATS:
            feats[f'hist{i}_{semb_base}'] = _generate_hist_data(num_samples, SEQ_MAX_LENS[i], feats[f'seq{i}_length'], IID_SIZE if semb_base == 'item_id' else FEAT_SIZE)

    return feats

def reshape_single_element_arrays(d):
    for key, value in d.items():
        if isinstance(value, np.ndarray):
            if value.ndim == 1 and value.size == 1:
                d[key] = value.reshape(1, 1)
    return d

import time
import concurrent.futures
from functools import wraps

NUM_REPEATS = 512

def timer_decorator(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        start_time = time.perf_counter()
        result = func(*args, **kwargs)
        end_time = time.perf_counter()
        return end_time - start_time, result
    return wrapper

def concurrency_decorator(concurrency_levels):
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            latencies = {}
            for concurrency in concurrency_levels:
                print(f"Testing with concurrency level: {concurrency}")
                latencies_c = []
                
                with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as executor:
                    # futures = [executor.submit(func, i, i) for i in range(concurrency)]

                    for i in range(NUM_REPEATS):
                        futures = [executor.submit(func) for _ in range(concurrency)]

                        for future in concurrent.futures.as_completed(futures):
                            try:
                                time_elapse, func_result = future.result()
                                func_data = [i.item() for i in func_result]
                                latencies_c.append((time_elapse, []))
                            except Exception as exc:
                                print(f'generated exception: {exc}')

                latencies[concurrency] = latencies_c

                print(f'Sleep between concurrency levels.')
                time.sleep(2)
            
            return latencies
        return wrapper
    return decorator