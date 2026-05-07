#!/bin/bash

# 1. 系统依赖
sudo apt update
sudo apt install -y python3-pip python3-venv git amazon-ec2-utils

# 2. 创建虚拟环境
python3 -m venv ~/whisper-env
source ~/whisper-env/bin/activate

# 3. 安装 faster-whisper
pip install faster-whisper dool

# 4. 验证安装
python3 -c "from faster_whisper import WhisperModel; print('OK')"

# 5. 运行测试脚本
git clone https://github.com/SYSTRAN/faster-whisper.git
cp faster-whisper/tests/data/physicsworks.wav .
curl -A "Mozilla/5.0" -O https://www.americanrhetoric.com/mp3clipsXE/stateoftheunion/barackobamasou2016ARXE.mp3

cat <<EOL > test_faster_whisper.py
import sys
import time
from faster_whisper import WhisperModel

audio_file = sys.argv[1]
compute_type = sys.argv[2]

# 1. 模型加载时间
t0 = time.time()
model = WhisperModel(
    "base",
    device="cpu",
    compute_type=compute_type,
    cpu_threads=16,
)
t_load = time.time() - t0

# 2. 预处理时间（返回生成器，但实际 workload 还没开始）
t0 = time.time()
segments, info = model.transcribe(audio_file)
t_preprocess = time.time() - t0

# 3. 真正的转录时间（强制遍历完生成器）
t0 = time.time()
segments_list = list(segments)  # 触发所有识别计算
t_transcribe = time.time() - t0

# 4. 打印结果
print(f"File: {audio_file}, Compute: {compute_type}")
print(f"Language: {info.language}, Probability: {info.language_probability:.2f}")
for segment in segments_list:
    print(f"[{segment.start:.2f}s -> {segment.end:.2f}s] {segment.text}")

# 5. 输出时间分解
print(f"\n--- Timing ---")
print(f"Model load:   {t_load:.2f}s")
print(f"Preprocess:   {t_preprocess:.2f}s")
print(f"Transcribe:   {t_transcribe:.2f}s")
print(f"Total:        {t_load + t_preprocess + t_transcribe:.2f}s")

EOL

time python3 test_faster_whisper.py barackobamasou2016ARXE.mp3 float32