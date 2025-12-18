import numpy as np
from sklearn.datasets import make_classification
import xgboost as xgb
import time

# https://xgboosting.com/xgboost-benchmark-model-training-time/

# Generate a synthetic dataset
X, y = make_classification(n_samples=1000000, n_features=100, n_informative=80,
                           n_redundant=10, n_classes=2, random_state=42)

# Create DMatrix for XGBoost
dtrain = xgb.DMatrix(X, label=y)

# Define a function to train an XGBoost model with a specified number of threads
def train_model(nthread):
    params = {'objective': 'binary:logistic', 'nthread': nthread, 'eval_metric': 'error',
              'max_depth': 6, 'eta': 0.1}
    start_time = time.perf_counter()
    xgb.train(params, dtrain, num_boost_round=100)
    end_time = time.perf_counter()
    return end_time - start_time

# Benchmark training time with different numbers of threads
num_threads = [1, 2, 4, 8]
training_times = []

for nt in num_threads:
    elapsed_time = train_model(nt)
    training_times.append(elapsed_time)
    print(f"Training with {nt} thread(s) took {elapsed_time:.2f} seconds.")

# Print results in a table
print("\nBenchmark Results:")
print("Threads | Training Time (s)")
print("--------|------------------")
for nt, tt in zip(num_threads, training_times):
    print(f"{nt:7d} | {tt:17.2f}")

# Benchmark Results:
# Threads | Training Time (s)
# --------|------------------
#       1 |             38.41
#       2 |             13.38
#       4 |              6.95
#       8 |              6.90