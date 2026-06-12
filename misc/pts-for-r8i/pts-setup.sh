#!/bin/bash

install_al2023_dependencies () {
  echo "------ INSTALLING UTILITIES ------"
  yum -yq update
  yum install -yq dmidecode vim unzip git screen wget p7zip
  yum -yq groupinstall "Development Tools"
  yum install -yq glibc blas blas-devel openssl-devel libXext-devel libX11-devel libXaw libXaw-devel mesa-libGL-devel 
  yum install -yq python3 python3-pip python3-devel cargo java-17-amazon-corretto java-17-amazon-corretto-devel
  yum install -yq php8.4 php8.4-cli php-json php8.4-xml perl-IPC-Cmd
  pip3 install dool

  echo "------ INSTALLING HIGH LEVEL PERFORMANCE TOOLS ------"
  yum install -yq sysstat hwloc hwloc-gui util-linux numactl tcpdump htop iotop iftop 

  echo "------ INSTALLING LOW LEVEL PERFORAMANCE TOOLS ------"
  yum install -yq perf kernel-devel-$(uname -r) bcc

  echo "------ INSTALL ANALYSIS TOOLS AND DEPENDENCIES ------"
#   curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
#   python3 get-pip.py
  python3 -m pip install pandas numpy scipy matplotlib sh seaborn plotext
#   git clone https://github.com/brendangregg/FlameGraph.git FlameGraph
  
  echo "------ DONE ------"
}

# # 配置 AWSCLI
# cd /root/
# yum remove -y awscli
# ARCH=$(arch)
# curl "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o "awscliv2.zip"
# unzip -q awscliv2.zip
# ./aws/install
# cp -rf /usr/local/bin/aws /usr/bin/aws
# aws --version

# aws_ak_value="akxxx"
# aws_sk_value="skxxx"
# aws_region_name=$(ec2-metadata --quiet --region)
# aws_s3_bucket_name=$(aws s3 ls | awk '{print $3}' | grep ec2-core-benchmark | head -1)
# aws configure set aws_access_key_id ${aws_ak_value}
# aws configure set aws_secret_access_key ${aws_sk_value}
# aws configure set default.region ${aws_region_name}

# 主要流程
OS_NAME=$(egrep ^NAME /etc/os-release | awk -F "\"" '{print $2}')
OS_VERSION=$(egrep ^VERSION_ID /etc/os-release | awk -F "\"" '{print $2}')
ARCH=$(arch)

install_al2023_dependencies

## 更新 cmake
ARCH=$(arch) 
VER=3.29.6
wget https://github.com/Kitware/CMake/releases/download/v${VER}/cmake-${VER}-linux-${ARCH}.sh
sh cmake-${VER}-linux-${ARCH}.sh --skip-license --prefix=/usr
cmake -version

## 获取机型规格、kernel 版本，创建保存输出文件的目录。
cd /root/
PN=$(ec2-metadata --quiet --instance-type)
KERNEL_RELEASE=$(uname -r)
DATA_DIR=~/${PN}_hwinfo_${KERNEL_RELEASE}
CFG_DIR=${DATA_DIR}/system-infomation
PTS_RESULT_DIR=${DATA_DIR}/pts-result
LOG_DIR=${DATA_DIR}/logs
mkdir -p ${DATA_DIR}  ${CFG_DIR} ${PTS_RESULT_DIR} ${LOG_DIR} 

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
lstopo -p --of png > ${CFG_DIR}/cfg_lstopo-physical.png
lstopo -l --of png > ${CFG_DIR}/cfg_lstopo-logical.png
lstopo -l > ${CFG_DIR}/cfg_lstopo-l.txt
lstopo -p > ${CFG_DIR}/cfg_lstopo-p.txt
lstopo --of png > ${CFG_DIR}/cfg_lstopo-all.png
numactl -H > ${CFG_DIR}/cfg_numactl-H.txt
uname -a > ${CFG_DIR}/cfg_uname-a.txt

## core-to-core-latency 测试 ===========================================================
cargo install core-to-core-latency
python3 -m pip install cython numpy pandas matplotlib
curl -o ~/heatmap.py https://raw.githubusercontent.com/eric-yq/ec2-test-suite/refs/heads/main/tools/heatmap.py
## 测试 core-to-core-latency，并通过 heatmap.py 生成热力图，执行3次。
cpu_model=$(dmidecode -t Processor | grep -i Version | awk -F':'  '{print $2}' | sed s"/^ //g")
NPROCS=$(nproc)
for i in {1..3} 
do
	~/.cargo/bin/core-to-core-latency 5000 --csv > ${CFG_DIR}/perf-core-to-core-latency-${i}.csv
	python3 ~/heatmap.py -f "${CFG_DIR}/perf-core-to-core-latency-${i}.csv" -o "${CFG_DIR}/perf-core-to-core-latency-heatmap-${i}.png" -c "${cpu_model}" -n ${NPROCS}
	sleep 5
done

##############################################################################################
## PTS（Phoronix-Test-Suite）基准测试
## 安装依赖包,master 分支的代码需要修改才能正常运行，使用 10.8.4 的稳定版本。
# git clone https://github.com/phoronix-test-suite/phoronix-test-suite.git ~/phoronix-test-suite
wget https://github.com/phoronix-test-suite/phoronix-test-suite/releases/download/v10.8.4/phoronix-test-suite-10.8.4.tar.gz
tar zxf phoronix-test-suite-10.8.4.tar.gz
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

# 安装新测试项目需要的软件包
yum install -yq lz4-devel lzo-devel libcurl-devel bzip2-devel
python3 -m pip install sklearn scons
DOWNLOAD_FILE="ffmpeg-master-latest-linux$([ "$(uname -m)" = "aarch64" ] && echo "arm" || echo "")64-gpl"
DOWNLOAD_URL="https://github.com/BtbN/FFmpeg-Builds/releases/download/latest"
wget ${DOWNLOAD_URL}/${DOWNLOAD_FILE}.tar.xz
tar xf ${DOWNLOAD_FILE}.tar.xz
cp ${DOWNLOAD_FILE}/bin/ffmpeg /usr/local/bin/ && rm -rf ${DOWNLOAD_FILE}*

