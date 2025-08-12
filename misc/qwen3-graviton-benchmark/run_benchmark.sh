#!/bin/bash

# Qwen3-0.6B-BF16 Benchmark Runner
# 适用于 c7i.2xlarge 和 c8g.2xlarge 实例

set -e

echo "=== Qwen3-0.6B-BF16 Benchmark Setup ==="

# 检测实例类型
INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null || echo "unknown")
export EC2_INSTANCE_TYPE=$INSTANCE_TYPE
echo "Instance Type: $INSTANCE_TYPE"

# 检测架构
ARCH=$(uname -m)
echo "Architecture: $ARCH"

# 创建虚拟环境（如果不存在）
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# 激活虚拟环境
source venv/bin/activate

# 升级pip
pip install --upgrade pip

# 根据架构安装PyTorch
if [[ "$ARCH" == "aarch64" ]]; then
    echo "Installing PyTorch for ARM64 (Graviton)..."
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
else
    echo "Installing PyTorch for x86_64 (Intel)..."
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
fi

# 安装其他依赖
echo "Installing other dependencies..."
pip install -r requirements.txt

# 设置环境变量
export TOKENIZERS_PARALLELISM=false
export OMP_NUM_THREADS=$(nproc)

# 运行benchmark
echo "Starting benchmark..."
python3 qwen3_benchmark.py --model "Qwen/Qwen3-0.6B-BF16" --device cpu

echo "Benchmark completed!"
echo "Results saved in qwen3_benchmark_${INSTANCE_TYPE}_*.json"
