#!/bin/bash

# 补充测试 pyperformance, cpp-perf-bench, keydb, smallpt


## 暂时关闭补丁更新流程
sudo systemctl stop amazon-ssm-agent
sudo systemctl disable amazon-ssm-agent
################################################################################################################ 

SUT_NAME="SUT_XXX"

install_al2023_dependencies () {
  echo "------ INSTALLING UTILITIES ------"
  yum -yq update
  yum install -yq dmidecode vim unzip git screen wget p7zip
  yum -yq groupinstall "Development Tools"
  yum install -yq glibc blas blas-devel openssl-devel libXext-devel libX11-devel libXaw libXaw-devel mesa-libGL-devel 
  yum install -yq python3 python3-pip python3-devel cargo java-17-amazon-corretto java-17-amazon-corretto-devel
  yum install -yq php8.4 php8.4-cli php-json php8.4-xml perl-IPC-Cmd
  # 使用 GCC 14 编译
  yum install -yq gcc14*

  pip3 install dool

  echo "------ INSTALLING HIGH LEVEL PERFORMANCE TOOLS ------"
  yum install -yq sysstat hwloc hwloc-gui util-linux numactl tcpdump htop iotop iftop 

  echo "------ INSTALLING LOW LEVEL PERFORAMANCE TOOLS ------"
  yum install -yq perf kernel-devel-$(uname -r) bcc

  echo "------ INSTALL ANALYSIS TOOLS AND DEPENDENCIES ------"
  python3 -m pip install pandas numpy scipy matplotlib sh seaborn plotext

  echo "------ DONE ------"
}

# 配置 AWSCLI
cd /root/
yum remove -y awscli
ARCH=$(arch)
curl "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
cp -rf /usr/local/bin/aws /usr/bin/aws
aws --version

aws_ak_value="akxxx"
aws_sk_value="skxxx"
aws_region_name=$(cloud-init query region)
aws configure set aws_access_key_id ${aws_ak_value}
aws configure set aws_secret_access_key ${aws_sk_value}
aws configure set default.region ${aws_region_name}
aws_s3_bucket_name="s3://ec2-core-benchmark-ericyq"


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
## 设置测试项执行结束后，删除测试项以节省空间
echo "export REMOVE_TESTS_ON_COMPLETION=TRUE" >> /root/.bashrc
## 关闭 checksum
echo "export NO_FILE_HASH_CHECKS=1" >> /root/.bashrc
## 设置 GCC14
echo "export CC=/usr/bin/gcc14-cc" >> /root/.bashrc
echo "export CXX=/usr/bin/gcc14-g++" >> /root/.bashrc
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
## 安装依赖包,master 分支的代码需要修改才能正常运行，使用 10.8.4 的稳定版本。
# git clone https://github.com/phoronix-test-suite/phoronix-test-suite.git ~/phoronix-test-suite
wget https://github.com/phoronix-test-suite/phoronix-test-suite/releases/download/v10.8.4/phoronix-test-suite-10.8.4.tar.gz
tar zxf phoronix-test-suite-10.8.4.tar.gz
cd ~/phoronix-test-suite/pts-core/commands/
cp ./batch_setup.php ./batch_setup.php.original.bak
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

# 安装新测试项目需要的软件包
yum install -yq lz4-devel lzo-devel libcurl-devel bzip2-devel
python3 -m pip install sklearn scons
DOWNLOAD_FILE="ffmpeg-master-latest-linux$([ "$(uname -m)" = "aarch64" ] && echo "arm" || echo "")64-gpl"
DOWNLOAD_URL="https://github.com/BtbN/FFmpeg-Builds/releases/download/latest"
wget ${DOWNLOAD_URL}/${DOWNLOAD_FILE}.tar.xz
tar xf ${DOWNLOAD_FILE}.tar.xz
cp ${DOWNLOAD_FILE}/bin/ffmpeg /usr/local/bin/ && rm -rf ${DOWNLOAD_FILE}*

 
tests="sample-program"
for testname in ${tests} 
do
    # 启动一个监控
    DOOL_FILE="${PTS_RESULT_DIR}/${testname}-dool.txt"
    dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 30 > ${DOOL_FILE} 2>&1 &
    DOOL_PID=$!
    # 执行基准测试
    FORCE_TIMES_TO_RUN=3 phoronix-test-suite batch-benchmark ${testname} > ${PTS_RESULT_DIR}/${testname}.txt
    # 保存结果 URL
    echo "${testname}:" >> ${DATA_DIR}/test-report-url-summary.txt
    phoronix-test-suite info ${testname} | grep "Description: "  >> ${DATA_DIR}/test-report-url-summary.txt
    grep "Results Uploaded To" ${PTS_RESULT_DIR}/${testname}.txt >> ${DATA_DIR}/test-report-url-summary.txt
    # 停止监控
    kill -9 ${DOOL_PID}

    sleep 5
done

## pyperformance 需要使用 python 3.10 以上
tests1="pyperformance"
for testname in ${tests1} 
do
    yum install -yq python3.14*
    python3.14 -m venv ~/venv-py314

    # 进入 python 3.14 虚拟环境
    source ~/venv-py314/bin/activate
    phoronix-test-suite download-test-files pyperformance
    cd /var/lib/phoronix-test-suite/test-profiles/pts/pyperformance-1.2.0
    sed -i.bak "s/--user//g" install.sh
    phoronix-test-suite install pyperformance
    cd /var/lib/phoronix-test-suite/installed-tests/pts/pyperformance-1.2.0/
    mkdir -p .local/bin/
    cp /root/venv-py314/bin/pyperformance .local/bin/
    
    cd ~
    
    # 启动一个监控
    DOOL_FILE="${PTS_RESULT_DIR}/${testname}-dool.txt"
    dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60 > ${DOOL_FILE} 2>&1 &
    DOOL_PID=$!
    phoronix-test-suite install ${testname}
    cd
    
    # 执行基准测试
    FORCE_TIMES_TO_RUN=1 phoronix-test-suite batch-benchmark ${testname} > ${PTS_RESULT_DIR}/${testname}.txt
    # 保存结果 URL
    echo "${testname}:" >> ${DATA_DIR}/test-report-url-summary.txt
    phoronix-test-suite info ${testname} | grep "Description: "  >> ${DATA_DIR}/test-report-url-summary.txt
    grep "Results Uploaded To" ${PTS_RESULT_DIR}/${testname}.txt >> ${DATA_DIR}/test-report-url-summary.txt
    # 停止监控
    kill -9 ${DOOL_PID}
    # 退出python 3.14 虚拟环境
    deactivate

    sleep 5
done

## 需要使用 GCC 低版本的测试项目，OS 中已经安装有 GCC（11） 和 GCC14
tests1="keydb cpp-perf-bench"
for testname in ${tests1} 
do
    # 启动一个监控
    DOOL_FILE="${PTS_RESULT_DIR}/${testname}-dool.txt"
    dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60 > ${DOOL_FILE} 2>&1 &
    DOOL_PID=$!
    # 执行基准测试
    FORCE_TIMES_TO_RUN=1 CC=gcc CXX=g++ \
      phoronix-test-suite batch-benchmark ${testname} > ${PTS_RESULT_DIR}/${testname}.txt
    # 保存结果 URL
    echo "${testname}:" >> ${DATA_DIR}/test-report-url-summary.txt
    phoronix-test-suite info ${testname} | grep "Description: "  >> ${DATA_DIR}/test-report-url-summary.txt
    grep "Results Uploaded To" ${PTS_RESULT_DIR}/${testname}.txt >> ${DATA_DIR}/test-report-url-summary.txt
    # 停止监控
    kill -9 ${DOOL_PID}

    sleep 5
done

# 所有结果打包并上传到 S3 bucket
phoronix-test-suite list-installed-tests > ${DATA_DIR}/pts-list-installed-tests.txt
ls -ltr ${PTS_RESULT_DIR} >> ${DATA_DIR}/pts-list-installed-tests.txt
df -h  >> ${DATA_DIR}/pts-list-installed-tests.txt
rm -rf ${LOG_DIR}/*
cp -r /var/log/cloud-init*.log /var/log/phoronix-test-suite-*.log /var/lib/cloud/ /root/userdata.sh ${LOG_DIR}
DATATIME=$(date +%Y%m%d.%H%M%S)
tar czfP ${DATA_DIR}-fix-failed-tests-${DATATIME}.tar.gz ${DATA_DIR}
aws_s3_bucket_name=$(aws s3 ls | awk '{print $3}' | grep ec2-core-benchmark | head -1)
aws s3 cp ${DATA_DIR}-fix-failed-tests-${DATATIME}.tar.gz s3://${aws_s3_bucket_name}/result_pts/ && \
echo "[INFO] Step3: Result files have been uploaded to s3 bucket. BYE BYE."


## Disable 服务，这样 reboot 后不会再次执行
# systemctl disable userdata.service

## 停止实例
INSTANCE_ID=$(ec2-metadata --quiet --instance-id)
aws ec2 stop-instances --instance-ids "${INSTANCE_ID}"
