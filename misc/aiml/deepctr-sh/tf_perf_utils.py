import os
import numpy as np

SEQ_SNAPSHOT_EMB = 192

def gen_emb_as_input(batch_size):
    
    eqv_embs = {
        'q_emb': np.random.rand(batch_size, 1, SEQ_SNAPSHOT_EMB).astype('float32'),
        'feats_embs': np.random.rand(batch_size, 1, 1216).astype('float32'),
        'seq1_emb': np.random.rand(batch_size, 200, SEQ_SNAPSHOT_EMB).astype('float32'),
        'seq2_emb': np.random.rand(batch_size, 100, SEQ_SNAPSHOT_EMB).astype('float32'),
        'seq3_emb': np.random.rand(batch_size, 50, SEQ_SNAPSHOT_EMB).astype('float32'),
        'seq4_emb': np.random.rand(batch_size, 50, SEQ_SNAPSHOT_EMB).astype('float32'),
        'seq0_length': np.random.randint(1, 201, size=(batch_size,1), dtype='uint8'),
        'seq1_length': np.random.randint(1, 101, size=(batch_size,1), dtype='uint8'),
        'seq2_length': np.random.randint(1, 51, size=(batch_size,1), dtype='uint8'),
        'seq3_length': np.random.randint(1, 51, size=(batch_size,1), dtype='uint8')
    }

    return eqv_embs


import time
import concurrent.futures
from functools import wraps

NUM_REPEATS = 32

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
                                # func_data = [i.item() for i in func_result]
                                latencies_c.append((time_elapse, func_result[0]))
                            except Exception as exc:
                                print(f'generated exception: {exc}')

                latencies[concurrency] = latencies_c

                print(f'Sleep between concurrency levels.')
                time.sleep(2)
            
            return latencies
        return wrapper
    return decorator