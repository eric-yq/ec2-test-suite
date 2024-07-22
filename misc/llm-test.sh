#!/bin/bash 


# Ubuntu 22.04 安装 PTS

cd /root/

###################################################################################################
# 安装需求包
apt update
apt install -y build-essential vim unzip git lsb-release grub2-common net-tools dmidecode hwloc util-linux numactl screen wget zip p7zip php php-cli php-json php-xml php-curl python3-pip python3-dev cargo libssl-dev libcurl4-openssl-dev libpcap-dev liblzma-dev scons

echo "------ INSTALLING PERFORMANCE TOOLS ------"
apt install -y sysstat hwloc tcpdump dstat htop iotop iftop nload stress-ng \
  linux-tools-$(uname -r) linux-headers-$(uname -r) linux-modules-extra-$(uname -r) bpfcc-tools

pip install --upgrade pip

## 更新 cmake
ARCH=$(arch) 
VER=3.29.6
wget https://github.com/Kitware/CMake/releases/download/v${VER}/cmake-${VER}-linux-${ARCH}.sh
sh cmake-${VER}-linux-${ARCH}.sh --skip-license --prefix=/usr
cmake -version

## 获取机型规格、kernel 版本，创建保存输出文件的目录。
cd /root/
PN=$(dmidecode -s system-product-name | tr ' ' '_')
KERNEL_RELEASE=$(uname -r)
DATA_DIR=~/${PN}_hwinfo_${KERNEL_RELEASE}
CFG_DIR=${DATA_DIR}/system-infomation
PTS_RESULT_DIR=${DATA_DIR}/pts-result
LOG_DIR=${DATA_DIR}/logs
mkdir -p ${DATA_DIR} ${CFG_DIR} ${PTS_RESULT_DIR} ${LOG_DIR} 

echo "export DATA_DIR=${DATA_DIR}" >> /root/.bashrc
echo "export CFG_DIR=${CFG_DIR}" >> /root/.bashrc
echo "export PTS_RESULT_DIR=${PTS_RESULT_DIR}" >> /root/.bashrc
echo "export LOG_DIR=${LOG_DIR}" >> /root/.bashrc
echo "export PN=${PN}" >> /root/.bashrc
echo "export TEST_RESULTS_IDENTIFIER=${PN}" >> /root/.bashrc
echo "export TEST_RESULTS_DESCRIPTION=${PN}" >> /root/.bashrc
echo "export TEST_RESULTS_NAME=${PN}" >> /root/.bashrc
source /root/.bashrc

## 收集系统信息
dmidecode > ${CFG_DIR}/cfg_dmidecode.txt
cat /proc/cpuinfo > ${CFG_DIR}/cfg_proc-cpuinfo.txt
lscpu > ${CFG_DIR}/cfg_lscpu.txt
lscpu --extended > ${CFG_DIR}/cfg_lscpu-extended.txt
lstopo -p --no-io --of png > ${CFG_DIR}/cfg_lstopo-physical.png
lstopo -l --no-io --of png > ${CFG_DIR}/cfg_lstopo-logical.png
lstopo -l > ${CFG_DIR}/cfg_lstopo-l.txt
lstopo -p > ${CFG_DIR}/cfg_lstopo-p.txt
numactl -H > ${CFG_DIR}/cfg_numactl-H.txt
uname -a > ${CFG_DIR}/cfg_uname-a.txt

###################################################################################################
## PTS（Phoronix-Test-Suite）基准测试
## 安装依赖包
git clone https://github.com/phoronix-test-suite/phoronix-test-suite.git ~/phoronix-test-suite
cd ~/phoronix-test-suite/pts-core/commands/
cp ./batch_setup.php ./batch_setup.php.original.bak
sed s:"test identifier', true":"test identifier', false":g ./batch_setup.php > ./batch_setup.php.1
sed s:"test description', true":"test description', false":g ./batch_setup.php.1 > ./batch_setup.php.2
sed s:"saved results file-name', true":"saved results file-name', false":g ./batch_setup.php.2 > ./batch_setup.php
cd ~/phoronix-test-suite/
./install-sh
## PTS：setup default user-configuration in /etc/phoronix-test-suite.xml
### following command use /usr/share/phoronix-test-suite/pts-core/commands/batch_setup.php
phoronix-test-suite batch-setup
export TEST_RESULTS_IDENTIFIER=${PN}
export TEST_RESULTS_DESCRIPTION=${PN}
export TEST_RESULTS_NAME=${PN}
echo "[Info] Install PTS successfully. "

###################################################################################################
## 安装 conda（下面这些需要基于特定版本 python 进行测试。）
cd /root/
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(arch).sh
bash Miniconda3-latest-Linux-$(arch).sh -b -p /root/miniconda3/
eval "$(/root/miniconda3/bin/conda shell.bash hook)"
conda init
source /root/.bashrc
echo "[Info] Install Miniconda successfully. "

## 安装 huggingface-cli
pip install -U "huggingface_hub[cli]"


###################################################################################################
# 构建 llama.cpp
cd /root/
apt install -y libopenblas-dev

git clone https://github.com/ggerganov/llama.cpp.git
cd /root/llama.cpp
make -j $(nproc) LLAMA_CURL=ON GGML_OPENBLAS=1
ln -s /root/llama.cpp/llama-cli /usr/local/bin/llama-cli
chmod +x /usr/local/bin/llama-cli

## 生成运行 llama.cpp 的脚本
cat << EOF > /usr/local/bin/run-llama-cpp
#!/bin/sh

id=\$1
name=\$(echo \$2 | sed 's/\//__/g')

LOG_REPO="/root/logs_of_llama.cpp/\$id/"
LOG_FILE="\$LOG_REPO/\$name.log"
PROMPTS_REPO="/root/prompts_repo"
mkdir -p \$LOG_REPO


echo "[Info] \$(date +%Y%m%d.%H%M%S) Start to generate contents using Model \$name ...... " 
echo "[Info] \$(date +%Y%m%d.%H%M%S) Progress and log file:  \$LOG_FILE " 
echo "[Info] \$(date +%Y%m%d.%H%M%S) The output of prompt file \$3 and llama_print_timings: " >> \$LOG_FILE 
  
llama-cli --hf-repo \$id --hf-file \$name -f \$PROMPTS_REPO/\$3.txt \
  --color --ctx_size 4096 >> \$LOG_FILE 2>&1

grep "llama_print_timings:" \$LOG_FILE 
echo "[Info] \$(date +%Y%m%d.%H%M%S) Complete Successfully. " 

EOF
chmod +x /usr/local/bin/run-llama-cpp


## 常用路径
MODEL_ZOO="/root/gguf_model_zoo"
PROMPTS_REPO="/root/prompts_repo"
mkdir -p $MODEL_ZOO $PROMPTS_REPO

## 常用路径加入环境变量
cat << EOF >> /root/.bashrc
export MODEL_ZOO="/root/gguf_model_zoo"
export PROMPTS_REPO="/root/prompts_repo"
EOF
source /root/.bashrc

## 生成提示词文件
cat << EOF > $PROMPTS_REPO/01.txt
Building a website can be done in 10 simple steps. 
EOF
cat << EOF > $PROMPTS_REPO/02.txt
Introduce AWS Graviton3 CPU processor, and tell me how to optimize C/C++ application on Graviton-based EC2 instances. 
EOF
cat << EOF > $PROMPTS_REPO/03.txt
Introduce Raphael's 5 most famous works, including the title, year of creation, size and material, and which museum or gallery they are currently in. Please describe each work in 300 words or less.
EOF
cat << EOF > $PROMPTS_REPO/04.txt
介绍一下拉斐尔最著名的 5 幅作品，它们的名称、创作年份、尺寸、材质、保存在哪个博物馆或者美术馆，以及这幅作品所描述的内容是什么。
EOF
cat << EOF > $PROMPTS_REPO/05.txt
介绍意大利文艺复兴时期的佛罗伦萨画派和威尼斯画派，这两个画派各自公认的最著名的 3 位画家的生卒年月和出生地点，以及每位画家最著名的 5 幅作品，并详细介绍每幅作品的名称、创作年份、尺寸、材质、保存在哪个博物馆或者美术馆，以及这幅作品所描述的内容是什么。
EOF


#################################################
## Model: TinyLlama-1.1B-Chat-v1.0-GGU
repo_id="TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF"
filenames="tinyllama-1.1b-chat-v1.0.Q8_0.gguf"
run-llama-cpp $repo_id $filenames 01
run-llama-cpp $repo_id $filenames 02
run-llama-cpp $repo_id $filenames 03

#################################################
## Model: Llama-2-7B-Chat-GGUF
repo_id="TheBloke/Llama-2-7B-Chat-GGUF"
filenames="llama-2-7b-chat.Q5_K_M.gguf"
run-llama-cpp $repo_id $filenames 01
run-llama-cpp $repo_id $filenames 02
run-llama-cpp $repo_id $filenames 03

#################################################
## Model: Meta-Llama-3-8B-Instruct-GGUF
repo_id="lmstudio-community/Meta-Llama-3-8B-Instruct-GGUF"
filenames="Meta-Llama-3-8B-Instruct-Q8_0.gguf"
run-llama-cpp $repo_id $filenames 01
run-llama-cpp $repo_id $filenames 02
run-llama-cpp $repo_id $filenames 03

#################################################
## Model: Mistral-7B-Instruct-v0.3-GGUF
repo_id="MaziyarPanahi/Mistral-7B-Instruct-v0.3-GGUF"
filenames="Mistral-7B-Instruct-v0.3.Q8_0.gguf"
run-llama-cpp $repo_id $filenames 01
run-llama-cpp $repo_id $filenames 02
run-llama-cpp $repo_id $filenames 03

#################################################
## Model: Phi-3-mini-4k-instruct-gguf
repo_id="microsoft/Phi-3-mini-4k-instruct-gguf"
filenames="Phi-3-mini-4k-instruct-q4.gguf"
run-llama-cpp $repo_id $filenames 01
run-llama-cpp $repo_id $filenames 02
run-llama-cpp $repo_id $filenames 03

#################################################
## Model: Phi-3-medium-128k-instruct-GGUF
repo_id="bartowski/Phi-3-medium-128k-instruct-GGUF"
filenames="Phi-3-medium-128k-instruct-Q5_K_M.gguf"
run-llama-cpp $repo_id $filenames 01
run-llama-cpp $repo_id $filenames 02
run-llama-cpp $repo_id $filenames 03

#################################################
## Model: gemma-2-9b-it-GGUF
repo_id="bartowski/gemma-2-9b-it-GGUF"
filenames="gemma-2-9b-it-Q5_K_M.gguf"
run-llama-cpp $repo_id $filenames 01
run-llama-cpp $repo_id $filenames 02
run-llama-cpp $repo_id $filenames 03

#################################################
## Model: gemma-2-27b-it-GGUF
repo_id="bartowski/gemma-2-27b-it-GGUF"
filenames="gemma-2-27b-it-Q5_K_M.gguf"
run-llama-cpp $repo_id $filenames 01
run-llama-cpp $repo_id $filenames 02
run-llama-cpp $repo_id $filenames 03

#################################################
# ## Model: Grok-1-GGUF
# repo_id="Arki05/Grok-1-GGUF"
# filenames="gemma-2-27b-it-Q5_K_M.gguf"
# run-llama-cpp $repo_id $filenames 01
# run-llama-cpp $repo_id $filenames 02
# run-llama-cpp $repo_id $filenames 03

#################################################
## Model: Starling-LM-7B-alpha-GGUF
repo_id="TheBloke/Starling-LM-7B-alpha-GGUF"
filenames="starling-lm-7b-alpha.Q5_K_M.gguf"
run-llama-cpp $repo_id $filenames 01
run-llama-cpp $repo_id $filenames 02
run-llama-cpp $repo_id $filenames 03

#################################################
## Model: llava-v1.5-7b-llamafile
repo_id="Mozilla/llava-v1.5-7b-llamafile"
filenames="llava-v1.5-7b-Q8_0.gguf"
run-llama-cpp $repo_id $filenames 01
run-llama-cpp $repo_id $filenames 02
run-llama-cpp $repo_id $filenames 03

#################################################
## Model: rocket-3B-GGUF
repo_id="TheBloke/rocket-3B-GGUF"
filenames="rocket-3b.Q5_K_M.gguf"
run-llama-cpp $repo_id $filenames 01
run-llama-cpp $repo_id $filenames 02
run-llama-cpp $repo_id $filenames 03

#################################################
## Model: SOLAR-10.7B-Instruct-v1.0-uncensored-GGUF
repo_id="TheBloke/SOLAR-10.7B-Instruct-v1.0-uncensored-GGUF"
filenames="solar-10.7b-instruct-v1.0-uncensored.Q5_K_M.gguf"
run-llama-cpp $repo_id $filenames 01
run-llama-cpp $repo_id $filenames 02
run-llama-cpp $repo_id $filenames 03

#################################################
## Model: llama-Chinese-Alpaca-2-7B-q4_0.gguf
repo_id="hfl/chinese-alpaca-2-7b-gguf"
filenames="ggml-model-q5_k-im.gguf"
run-llama-cpp $repo_id $filenames 04

#################################################
## Model: Gemma-2-9B-Chinese-Chat
repo_id="shenzhi-wang/Gemma-2-9B-Chinese-Chat"
filenames="gguf_models/gemma_2_chinese_chat_q8_0.gguf"
run-llama-cpp $repo_id $filenames 04

#################################################
## Model: Qwen2-7B-Instruct-GGUF
repo_id="Qwen/Qwen2-7B-Instruct-GGUF"
filenames="qwen2-7b-instruct-q5_k_m.gguf"
run-llama-cpp $repo_id $filenames 04

#################################################
## Model: Baichuan2-7B-Chat-GGUF
repo_id="second-state/Baichuan2-7B-Chat-GGUF"
filenames="Baichuan2-7B-Chat-Q5_K_M.gguf"
run-llama-cpp $repo_id $filenames 04

#################################################
## Model: 01-ai_-_Yi-1.5-9B-32K-gguf
repo_id="RichardErkhov/01-ai_-_Yi-1.5-9B-32K-gguf"
filenames="Yi-1.5-9B-32K.Q5_K_M.gguf"
run-llama-cpp $repo_id $filenames 04


























