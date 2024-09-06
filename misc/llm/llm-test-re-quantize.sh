#!/bin/bash 

## https://dev.to/aws-heroes/intro-to-llama-on-graviton-1dc

# Ubuntu 24.04 

cd /root/

# Install any prerequisites
sudo apt update
sudo apt install make cmake -y
sudo apt install gcc g++ -y
sudo apt install build-essential -y

# Build llama.cpp
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make -j$(nproc)

./llama-cli -h

# Set up a virtual environment for Python packages:
sudo apt install python-is-python3 python3-pip python3-venv -y
python -m venv venv
source venv/bin/activate

# Download model
huggingface-cli download cognitivecomputations/dolphin-2.9.4-llama3.1-8b-gguf dolphin-2.9.4-llama3.1-8b-Q4_0.gguf --local-dir . --local-dir-use-symlinks False

# Re-quantize the model：on Graviton3
QUANTIZE_METHOD="Q4_0_8_8"
./llama-quantize --allow-requantize dolphin-2.9.4-llama3.1-8b-Q4_0.gguf dolphin-2.9.4-llama3.1-8b-${QUANTIZE_METHOD}.gguf ${QUANTIZE_METHOD}

# Re-quantize the model：on Graviton4
QUANTIZE_METHOD="Q4_0_4_8"
./llama-quantize --allow-requantize dolphin-2.9.4-llama3.1-8b-Q4_0.gguf dolphin-2.9.4-llama3.1-8b-${QUANTIZE_METHOD}.gguf ${QUANTIZE_METHOD}


# Run inference with re-quantized model:
./llama-cli -m dolphin-2.9.4-llama3.1-8b-${QUANTIZE_METHOD}.gguf \
  -p "Building a visually appealing website can be done in ten simple steps:" \
  -n 512 -t 64
 
