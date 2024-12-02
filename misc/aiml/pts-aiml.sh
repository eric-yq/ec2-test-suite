#!/bin/bash
## Ubuntu 22.04 安装 PTS

apt update
apt install -y build-essential vim unzip git lsb-release grub2-common net-tools dmidecode hwloc util-linux numactl screen wget zip p7zip php php-cli php-json php-xml php-curl python3-pip python3-dev cargo libssl-dev libcurl4-openssl-dev libpcap-dev liblzma-dev scons
ln -s /usr/sbin/grub-mkconfig /usr/sbin/grub2-mkconfig

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

##############################################################################
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


###########################################################################################
## 开始测试（下面这些不需要 python 运行时）

## 单独处理 llamafile
# testname="llamafile"
# phoronix-test-suite install ${testname}
# sleep 10
# fff=/var/lib/phoronix-test-suite/installed-tests/pts/llamafile-1.2.0/llava-v1.6-mistral-7b.Q8_0.llamafile.86
# mv $fff.pts $fff && chmod +x $fff && ls -l $fff

## 1. onnx-1.17.0
testname="onnx"
phoronix-test-suite install ${testname} > ${PTS_RESULT_DIR}/${testname}.txt
cd /var/lib/phoronix-test-suite/test-profiles/pts/onnx-1.17.0/
sed -i.bak "s/--config/--allow_running_as_root --config/g" install.sh
cd /var/lib/phoronix-test-suite/installed-tests/pts/onnx-1.17.0/
rm FasterRCNN-12-int8.tar.gz arcfaceresnet100-8.tar.gz bertsquad-12.tar.gz gpt2-10.tar.gz 
wget https://github.com/onnx/models/raw/4c46cd00fbdb7cd30b6c1c17ab54f2e1f4f7b177/validated/vision/object_detection_segmentation/faster-rcnn/model/FasterRCNN-12-int8.tar.gz?download= -O FasterRCNN-12-int8.tar.gz
wget https://media.githubusercontent.com/media/onnx/models/4c46cd00fbdb7cd30b6c1c17ab54f2e1f4f7b177/validated/vision/body_analysis/arcface/model/arcfaceresnet100-8.tar.gz?download=true -O arcfaceresnet100-8.tar.gz
wget https://github.com/onnx/models/raw/4c46cd00fbdb7cd30b6c1c17ab54f2e1f4f7b177/validated/text/machine_comprehension/bert-squad/model/bertsquad-12.tar.gz?download= -O bertsquad-12.tar.gz
wget https://github.com/onnx/models/raw/4c46cd00fbdb7cd30b6c1c17ab54f2e1f4f7b177/validated/text/machine_comprehension/gpt-2/model/gpt2-10.tar.gz?download= -O gpt2-10.tar.gz
tar zxf FasterRCNN-12-int8.tar.gz
tar zxf arcfaceresnet100-8.tar.gz
tar zxf bertsquad-12.tar.gz 
tar zxf gpt2-10.tar.gz 
ls -l . >> ${PTS_RESULT_DIR}/${testname}.txt


## 批量
cd /root/
tests="llama-cpp whisper-cpp onnx openvino opencv onednn"
# llamafile：x86/arm 都有问题
# rnnoise: arm 有问题
for testname in ${tests} 
do
    phoronix-test-suite batch-benchmark ${testname} >> ${PTS_RESULT_DIR}/${testname}.txt
    echo "${testname}.txt:" >> ${DATA_DIR}/pts-result-url-summary.txt
    grep "Results Uploaded To" ${PTS_RESULT_DIR}/${testname}.txt >> ${DATA_DIR}/pts-result-url-summary.txt
    sleep 5
done

sleep 60

###########################################################################################
## 安装 conda（下面这些需要基于特定版本 python 进行测试。）
cd /root/
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(arch).sh
bash Miniconda3-latest-Linux-$(arch).sh -b -p /root/miniconda3/
eval "$(/root/miniconda3/bin/conda shell.bash hook)"
conda init
source /root/.bashrc


#########################################################################################
# PTS 测试： mlpack  ：OK
testname="mlpack"
conda create -y -q -n ${testname} python=3.7
cat << EOF > /root/${testname}.sh
#!/bin/bash
pip install pyyaml==3.13 scikit-learn numpy
phoronix-test-suite batch-benchmark ${testname} > ${PTS_RESULT_DIR}/${testname}.txt
echo "${testname}.txt:" >> ${DATA_DIR}/pts-result-url-summary.txt
grep "Results Uploaded To" ${PTS_RESULT_DIR}/${testname}.txt >> ${DATA_DIR}/pts-result-url-summary.txt
EOF
conda run -n ${testname} bash /root/${testname}.sh

#########################################################################################
# PTS 测试： scikit-learn   ：OK，arm 有点问题
testname="scikit-learn"


#########################################################################################
# PTS 测试： deepsparse  ：OK
testname="deepsparse"
conda create -y -q -n ${testname} python=3.10
cat << EOF > /root/${testname}.sh
#!/bin/bash
phoronix-test-suite batch-benchmark ${testname} > ${PTS_RESULT_DIR}/${testname}.txt
echo "${testname}.txt:" >> ${DATA_DIR}/pts-result-url-summary.txt
grep "Results Uploaded To" ${PTS_RESULT_DIR}/${testname}.txt >> ${DATA_DIR}/pts-result-url-summary.txt
EOF
conda run -n ${testname} bash /root/${testname}.sh

##########################################################################################
# # PTS 测试： ai-benchmark ：OK
# testname="ai-benchmark"
# conda create -y -q -n ${testname} python=3.7
# cat << EOF > /root/${testname}.sh
# #!/bin/bash
# pip install tensorflow==2.10.1 
# phoronix-test-suite batch-benchmark ${testname} > ${PTS_RESULT_DIR}/${testname}.txt
# echo "${testname}.txt:" >> ${DATA_DIR}/pts-result-url-summary.txt
# grep "Results Uploaded To" ${PTS_RESULT_DIR}/${testname}.txt >> ${DATA_DIR}/pts-result-url-summary.txt
# EOF
# conda run -n ${testname} bash /root/${testname}.sh

##########################################################################################
# 所有结果打包并上传到 S3 bucket
phoronix-test-suite list-installed-tests > ${DATA_DIR}/pts-list-installed-tests.txt
ls -ltr ${PTS_RESULT_DIR} >> ${DATA_DIR}/pts-list-installed-tests.txt
df -h  >> ${DATA_DIR}/pts-list-installed-tests.txt
rm -rf ${LOG_DIR}/*
cp -r /var/log/messages /var/log/cloud-init*.log /var/log/phoronix-test-suite-*.log /var/lib/cloud ${LOG_DIR}
tar czfP ${DATA_DIR}-all.tar.gz ${DATA_DIR}
