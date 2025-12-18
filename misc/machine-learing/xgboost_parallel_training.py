import os
# Avoid contention between processes
os.environ['OMP_NUM_THREADS'] = '1'
import numpy as np
from sklearn.datasets import make_classification
from xgboost import XGBClassifier
from concurrent.futures import ProcessPoolExecutor
import time

# Generate synthetic classification dataset
def generate_data():
    X, y = make_classification(n_samples=1000000, n_features=20, random_state=42)
    return X, y

# List of hyperparameter configurations
def get_params(n_jobs):
    return [
        {'n_estimators': 100, 'max_depth': 3, 'learning_rate': 0.1, 'n_jobs': n_jobs},
        {'n_estimators': 200, 'max_depth': 4, 'learning_rate': 0.05, 'n_jobs': n_jobs},
        {'n_estimators': 150, 'max_depth': 5, 'learning_rate': 0.08, 'n_jobs': n_jobs},
        {'n_estimators': 180, 'max_depth': 3, 'learning_rate': 0.12, 'n_jobs': n_jobs},
    ]

# Train single XGBoost model
def train_model(params):
    X, y = generate_data()
    model = XGBClassifier(**params)
    model.fit(X, y)

# Sequential model training
def train_sequential(param_sets):
    for params in param_sets:
        train_model(params)

# Parallel model training using multiprocessing
def train_parallel(param_sets):
    with ProcessPoolExecutor(4) as p:
        _ = [p.submit(train_model, ps) for ps in param_sets]

if __name__ == '__main__':
    # Time the sequential training
    start_sequential = time.perf_counter()
    train_sequential(get_params(4))
    end_sequential = time.perf_counter()
    print(f"Sequential training time: {end_sequential - start_sequential:.2f} seconds")

    # Time the parallel training
    start_parallel = time.perf_counter()
    train_parallel(get_params(2))
    end_parallel = time.perf_counter()
    print(f"Parallel training time: {end_parallel - start_parallel:.2f} seconds")

    # Calculate speedup
    speedup = (end_sequential - start_sequential) / (end_parallel - start_parallel)
    print(f"Parallel training is {speedup:.2f} times faster than sequential training")

# Sequential training time: 40.56 seconds
# Parallel training time: 12.83 seconds
# Parallel training is 3.16 times faster than sequential training