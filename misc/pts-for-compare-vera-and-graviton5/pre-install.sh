# m8gd.24xl, 96c, 384g, 3*1900GB NVME SSD
# m8gd.48xl, 192c, 768g, 6*1900GB NVME SSD
# Ubuntu 24.04

# 安装 AWSCLI
apt update
apt install -y unzip
ARCH=$(arch)
curl "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
cp -rf /usr/local/bin/aws /usr/bin/aws
aws --version 

# aws_ak_value="akxxx"
# aws_sk_value="skxxx"
# aws_region_name="us-west-2"
# aws_s3_bucket_name="s3://ec2-core-benchmark-ericyq"
# aws configure set aws_access_key_id ${aws_ak_value}
# aws configure set aws_secret_access_key ${aws_sk_value}
# aws configure set default.region ${aws_region_name}
# aws s3 ls

## 依赖关系
apt -y upgrade
apt install -y dmidecode vim unzip git screen wget p7zip-full git build-essential
apt install -y libc6-dev libblas-dev libblas3 libssl-dev libxext-dev libx11-dev libxaw7-dev libgl1-mesa-dev
apt install -y python3 python3-pip python3-dev cargo
apt install -y php php-cli php-json php-xml libperl-dev
apt install -y sysstat hwloc util-linux numactl tcpdump htop iotop iftop
apt install -y amazon-ec2-utils

# 更新 cmake
ARCH=$(arch) 
VER=3.29.6
wget https://github.com/Kitware/CMake/releases/download/v${VER}/cmake-${VER}-linux-${ARCH}.sh
sh cmake-${VER}-linux-${ARCH}.sh --skip-license --prefix=/usr
cmake -version

# 设置磁盘lvm stripe
cd /root/
git clone https://github.com/eric-yq/ec2-test-suite.git
bash ec2-test-suite/tools/setup_nvme_instance_store.sh

## 获取机型规格、kernel 版本，创建保存输出文件的目录。
cd /root/
PN=$(ec2-metadata --quiet --instance-type)
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
## 设置测试项安装在 /data/ 目录下(本地 SSD 盘)，避免占用 EBS 目录空间
echo "export PTS_DOWNLOAD_CACHE=/data/" >> /root/.bashrc
echo "export PTS_TEST_INSTALL_ROOT_PATH=/data/" >> /root/.bashrc
## 设置测试项执行结束后，删除测试项以节省空间
echo "export REMOVE_TESTS_ON_COMPLETION=TRUE" >> /root/.bashrc
source /root/.bashrc

## 收集系统信息
dmidecode > ${CFG_DIR}/cfg_dmidecode.txt
cat /proc/cpuinfo > ${CFG_DIR}/cfg_proc-cpuinfo.txt
lscpu > ${CFG_DIR}/cfg_lscpu.txt
lscpu --extended > ${CFG_DIR}/cfg_lscpu-extended.txt
lstopo -p --of png > ${CFG_DIR}/cfg_lstopo-physical.png
lstopo -l --of png > ${CFG_DIR}/cfg_lstopo-logical.png
lstopo -l > ${CFG_DIR}/cfg_lstopo-l.txt
lstopo -p > ${CFG_DIR}/cfg_lstopo-p.txt
lstopo --of png > ${CFG_DIR}/cfg_lstopo-all.png
numactl -H > ${CFG_DIR}/cfg_numactl-H.txt
uname -a > ${CFG_DIR}/cfg_uname-a.txt

##############################################################################################
## PTS（Phoronix-Test-Suite）基准测试
## 安装依赖包
cd ~
wget https://github.com/phoronix-test-suite/phoronix-test-suite/releases/download/v10.8.4/phoronix-test-suite-10.8.4.tar.gz
tar zxf phoronix-test-suite-10.8.4.tar.gz
cd ~/phoronix-test-suite/pts-core/commands/
sed -i.original.bak \
  -e "s:test identifier', true:test identifier', false:g" \
  -e "s:test description', true:test description', false:g" \
  -e "s:saved results file-name', true:saved results file-name', false:g" \
  ./batch_setup.php
cd ~/phoronix-test-suite/
./install-sh
## PTS：setup default user-configuration in /etc/phoronix-test-suite.xml
### following command use /usr/share/phoronix-test-suite/pts-core/commands/batch_setup.php
phoronix-test-suite batch-setup


###########################################################################################
# 测试集1：2605268-PTS-2605245P37
# https://openbenchmarking.org/result/2605268-PTS-2605245P37

# 解除 Ubuntu 24.04（Python 3.12）默认开启的 PEP 668 保护
sudo tee /etc/pip.conf >/dev/null <<'EOF'
[global]
break-system-packages = true
EOF

# 安装依赖关系
apt install -y openjdk-11-jdk yasm nasm scons libprotobuf-dev libboost-all-dev libasio-dev libboost-iostreams-dev \
bison flex libgoogle-perftools-dev libprotoc-dev pkgconf libxcursor-dev libxinerama-dev libasound2-dev libpulse-dev \
libudev-dev libxi-dev libxrandr-dev libelf-dev libpcre2-dev 

# 安装测试集
phoronix-test-suite install 2605268-PTS-2605245P37

# 执行测试集
FORCE_TIMES_TO_RUN=3 phoronix-test-suite batch-benchmark 2605268-PTS-2605245P37


##结果
# https://openbenchmarking.org/result/2608052-NE-2605268PT64
# https://openbenchmarking.org/result/2608052-NE-2605268PT20
# m9gd.48xlarge 和 Grace/Vera 结果对比（过滤掉NVIDIA Vera 杂音选型，保留 1 x NVIDIA Vera）
# https://openbenchmarking.org/result/2608052-NE-2605268PT64&hni=1&sgm=1&nor=1&rmm=2+x+EPYC+9455%2C2+x+EPYC+9475F%2C1+x+EPYC+9575F%2C2+x+EPYC+9575F%2C1+x+EPYC+9755%2C2+x+EPYC+9755%2C1+x+Xeon+6980P%2C2+x+Xeon+6980P%2CNVIDIA+Vera&ppt=D&sor#r-31f7120546092697a338db0afea1913679ec9502