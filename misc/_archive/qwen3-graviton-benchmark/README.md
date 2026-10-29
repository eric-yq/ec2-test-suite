# Qwen3-0.6B-BF16 Benchmark Suite

这是一个专门为比较 c7i.2xlarge (Intel) 和 c8g.2xlarge (Graviton) 实例上 Qwen3-0.6B-BF16 模型性能而设计的 benchmark 测试套件。

## 文件说明

- `qwen3_benchmark.py` - 主要的 benchmark 测试程序
- `run_benchmark.sh` - 自动化运行脚本
- `analyze_results.py` - 结果分析和比较脚本
- `requirements.txt` - Python 依赖包列表
- `README.md` - 本说明文档

## 功能特性

### 测试项目
1. **推理性能测试** - 测试不同 prompt 长度下的推理速度
2. **吞吐量测试** - 测试不同批次大小下的处理吞吐量
3. **内存使用测试** - 监控系统和GPU内存使用情况
4. **模型加载时间** - 测量模型加载和初始化时间

### 支持的实例类型
- **c7i.2xlarge** - Intel Xeon 第4代处理器 (8 vCPU, 16 GB RAM)
- **c8g.2xlarge** - AWS Graviton3 处理器 (8 vCPU, 16 GB RAM)

## 使用方法

### 1. 在 EC2 实例上运行 benchmark

#### 方法一：使用自动化脚本（推荐）
```bash
# 克隆或上传文件到 EC2 实例
# 运行自动化脚本
apt install -y python3.10-venv python3-pip
./run_benchmark.sh
```

#### 方法二：手动运行
```bash
# 安装依赖
pip install -r requirements.txt

# 设置环境变量
export EC2_INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
export TOKENIZERS_PARALLELISM=false

# 运行 benchmark
python3 qwen3_benchmark.py --model "Qwen/Qwen2.5-0.5B" --device cpu
python3 qwen3_benchmark.py --model "prithivMLmods/Qwen3-0.6B-ft-bf16" --device cpu
```

### 2. 分析和比较结果

在收集了两个实例的测试结果后：

```bash
# 分析所有结果文件
python3 analyze_results.py

# 指定特定的结果文件模式
python3 analyze_results.py --pattern "qwen3_benchmark_c*.json"

# 保存比较报告到指定文件
python3 analyze_results.py --output my_comparison_report.txt
```

## 输出文件

### Benchmark 结果文件
- 格式：`qwen3_benchmark_{instance_type}_{timestamp}.json`
- 包含完整的测试结果和系统信息

### 比较报告
- 格式：`benchmark_comparison_report.txt`
- 包含两个实例的性能对比分析

## 测试参数

### 推理性能测试
- Prompt 长度：50, 100, 200, 500 tokens
- 生成长度：100 tokens
- 重复次数：5次
- 统计指标：平均时间、标准差、tokens/second

### 吞吐量测试
- 批次大小：1, 2, 4
- 序列长度：100 tokens
- 批次数量：10
- 生成长度：50 tokens

### 内存监控
- 系统内存使用量
- GPU内存使用量（如果可用）
- 内存使用百分比

## 系统要求

### Python 环境
- Python 3.8+
- PyTorch 2.0+
- Transformers 4.35+

### 系统资源
- 最少 8GB RAM
- 足够的磁盘空间存储模型（约 2GB）
- 网络连接（首次下载模型）

## 注意事项

1. **首次运行**：第一次运行时会下载 Qwen2.5-0.5B 模型，需要网络连接和时间
2. **内存使用**：确保实例有足够内存加载模型
3. **CPU优化**：脚本会自动设置 `OMP_NUM_THREADS` 为 CPU 核心数
4. **结果准确性**：建议在相同的网络和负载条件下进行测试

## 结果解读

### 性能指标
- **Tokens/Second**：每秒生成的 token 数量，越高越好
- **Latency**：推理延迟时间，越低越好
- **Throughput**：批处理吞吐量，越高越好
- **Memory Usage**：内存使用量，影响成本效益

### 实例选择建议
- **c8g.2xlarge (Graviton)**：通常提供更好的性价比
- **c7i.2xlarge (Intel)**：可能在某些单线程任务上表现更好

## 故障排除

### 常见问题
1. **内存不足**：减少批次大小或使用更大的实例
2. **模型下载失败**：检查网络连接和 Hugging Face 访问
3. **依赖安装失败**：确保使用正确的 Python 版本和 pip

### 调试选项
```bash
# 使用特定模型
python3 qwen3_benchmark.py --model "path/to/local/model"

# 指定设备
python3 qwen3_benchmark.py --device cpu

# 自定义输出文件名
python3 qwen3_benchmark.py --output custom_results.json
```

## 扩展功能

可以通过修改脚本来：
- 测试其他模型大小
- 调整测试参数
- 添加更多性能指标
- 支持 GPU 测试（如果实例支持）

## 许可证

本项目遵循 MIT 许可证。
