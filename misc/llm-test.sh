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
# 1. llama.cpp
cd /root/
git clone https://github.com/ggerganov/llama.cpp.git
cd /root/llama.cpp
make -j $(nproc) LLAMA_CURL=ON
ln -s /root/llama.cpp/llama-cli /usr/bin/llama-cli

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

## 提示词文件
cat << EOF > $PROMPTS_REPO/01.txt
Building a website can be done in 10 simple steps. Please note that you should format your answers one line per step.
EOF
cat << EOF > $PROMPTS_REPO/02.txt
Introduce AWS Graviton3 CPU processor, and tell me how to optimize C/C++ application on Graviton-based instances. Please provide good readability when answering this question.
EOF
cat << EOF > $PROMPTS_REPO/03.txt
Introduce Raphael's 3 most famous works, including the title, year of creation, size and material, and which museum or gallery they are currently in. Please describe each work in 300 words or less. (Reminder: Please do not provide information that is irrelevant to the question)
EOF


#################################################
## Model: Meta-Llama-3-8B-Instruct-GGUF
repo_id="lmstudio-community/Meta-Llama-3-8B-Instruct-GGUF"
filenames="Meta-Llama-3-8B-Instruct-Q8_0.gguf"
./llama-cli --hf-repo $repo_id --hf-file $filenames --color -f $PROMPTS_REPO/01.txt 
./llama-cli --hf-repo $repo_id --hf-file $filenames --color -f $PROMPTS_REPO/02.txt
./llama-cli --hf-repo $repo_id --hf-file $filenames --color -f $PROMPTS_REPO/03.txt


#################################################
## Model: Mistral-7B-Instruct-v0.3-GGUF
repo_id="MaziyarPanahi/Mistral-7B-Instruct-v0.3-GGUF"
filenames="Mistral-7B-Instruct-v0.3.Q8_0.gguf"
./llama-cli --hf-repo $repo_id --hf-file $filenames --color -f $PROMPTS_REPO/01.txt 
./llama-cli --hf-repo $repo_id --hf-file $filenames --color -f $PROMPTS_REPO/02.txt
./llama-cli --hf-repo $repo_id --hf-file $filenames --color -f $PROMPTS_REPO/03.txt


#################################################
## Model:Phi-3-mini-4k-instruct-gguf"
repo_id="microsoft/Phi-3-mini-4k-instruct-gguf"
filenames="Phi-3-mini-4k-instruct-q4.gguf"
./llama-cli --hf-repo $repo_id --hf-file $filenames --color -f $PROMPTS_REPO/01.txt 
./llama-cli --hf-repo $repo_id --hf-file $filenames --color -f $PROMPTS_REPO/02.txt
./llama-cli --hf-repo $repo_id --hf-file $filenames --color -f $PROMPTS_REPO/03.txt

