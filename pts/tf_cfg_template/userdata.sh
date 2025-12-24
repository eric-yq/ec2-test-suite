#!/bin/bash

# 作为 cloud-init 脚本时，使用 root 用户执行

# 实例启动成功之后的首次启动 OS， /root/userdata.sh 不存在，创建该 userdata.sh 文件并设置开启自动执行该脚本。
if [ ! -f "/root/userdata.sh" ]; then
    echo "首次启动 OS, 未找到 /root/userdata.sh，准备创建..."
    # 复制文件
    cp /var/lib/cloud/instance/scripts/part-001 /root/userdata.sh
    chmod +x /root/userdata.sh
    # 创建 systemd 服务单元
    cat > /etc/systemd/system/userdata.service << EOF
[Unit]
Description=Execute userdata script at boot
After=network.target

[Service]
Type=oneshot
User=root
ExecStart=/root/userdata.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    # 启用服务
    systemctl daemon-reload
    systemctl enable userdata.service
    
    echo "已创建并启用 systemd 服务 userdata.service"

    ### 如果 5 分钟之后，实例没有重启，或者也有可能不需要重启，则开始启动服务执行后续安装过程。
    sleep 300
    systemctl start userdata.service
    exit 0
fi

########################################################################################################################

install_al2023_dependencies () {
  echo "------ INSTALLING UTILITIES ------"
  yum clean metadata
  yum -y update
  yum install -y -q dmidecode vim unzip git screen wget p7zip
  yum -y -q groupinstall "Development Tools"
  yum install -y -q glibc blas blas-devel openssl-devel libXext-devel libX11-devel libXaw libXaw-devel mesa-libGL-devel 
  yum install -y -q python3 python3-pip python3-devel cargo java-17-amazon-corretto java-17-amazon-corretto-devel
  yum install -y -q php php-cli php-json php-xml perl-IPC-Cmd
  pip3 install dool

  echo "------ INSTALLING HIGH LEVEL PERFORMANCE TOOLS ------"
  yum install -y -q sysstat  hwloc hwloc-gui util-linux numactl tcpdump htop iotop iftop 

  echo "------ INSTALLING LOW LEVEL PERFORAMANCE TOOLS ------"
  yum install -y -q perf kernel-devel-$(uname -r) bcc

  echo "------ INSTALL ANALYSIS TOOLS AND DEPENDENCIES ------"
  curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
  python3 get-pip.py
  python3 -m pip install pandas numpy scipy matplotlib sh seaborn plotext
  git clone https://github.com/brendangregg/FlameGraph.git FlameGraph
  
  echo "------ DONE ------"
}

# 配置 AWSCLI
cd /root/
yum remove -y awscli
ARCH=$(arch)
curl "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
cp -rf /usr/local/bin/aws /usr/bin/aws
aws --version

aws_ak_value="akxxx"
aws_sk_value="skxxx"
aws_region_name=$(cloud-init query region)
aws_s3_bucket_name="s3://ec2-core-benchmark-ericyq"
aws configure set aws_access_key_id ${aws_ak_value}
aws configure set aws_secret_access_key ${aws_sk_value}
aws configure set default.region ${aws_region_name}
aws s3 ls

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
PN=$(cloud-init query ds.meta_data.instance_type)
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
lstopo -p --no-io --of png > ${CFG_DIR}/cfg_lstopo-physical.png
lstopo -l --no-io --of png > ${CFG_DIR}/cfg_lstopo-logical.png
lstopo -l > ${CFG_DIR}/cfg_lstopo-l.txt
lstopo -p > ${CFG_DIR}/cfg_lstopo-p.txt
numactl -H > ${CFG_DIR}/cfg_numactl-H.txt
uname -a > ${CFG_DIR}/cfg_uname-a.txt

## core-to-core-latency 测试 ===========================================================
cargo install core-to-core-latency
pip3 install cython numpy pandas matplotlib
## 生成heatmap.py, 该py脚本用于生成 core-to-core-latency 的热力图 --BEGIN
cat > ~/heatmap.py << EOF
import pandas as pd
import numpy as np
from matplotlib import pyplot as plt
import argparse

parser = argparse.ArgumentParser(description='This program parse core-to-core-latency report and make heat map')
parser.add_argument('-f', '--file', type=str, help='core to core latency csv report', required=True)
parser.add_argument('-o', '--outputfile', type=str, help='processor latency heatmap', required=True)
parser.add_argument('-c', '--core', type=str, help='processor name', required=True)
parser.add_argument('-n', '--number', type=int, help='number of cores', required=True)
args = parser.parse_args()

def load_data(filename):
    m = np.array(pd.read_csv(filename, header=None))
    return np.tril(m) + np.tril(m).transpose()

def show_heapmap(m, title=None, subtitle=None, vmin=None, vmax=None, yticks=True, figsize=None):
    vmin = np.nanmin(m) if vmin is None else vmin
    vmax = np.nanmax(m) if vmax is None else vmax
    black_at = (vmin+3*vmax)/4
    subtitle = "Core-to-core latency" if subtitle is None else subtitle

    isnan = np.isnan(m)

    plt.rcParams['xtick.bottom'] = plt.rcParams['xtick.labelbottom'] = False
    plt.rcParams['xtick.top'] = plt.rcParams['xtick.labeltop'] = True

    figsize = np.array(m.shape)*0.3 + np.array([6,1]) if figsize is None else figsize
    fig, ax = plt.subplots(figsize=figsize, dpi=130)

    fig.patch.set_facecolor('w')

    plt.imshow(np.full_like(m, 0.7), vmin=0, vmax=1, cmap = 'gray') # for the alpha value
    plt.imshow(m, cmap = plt.cm.get_cmap('viridis'), vmin=vmin, vmax=vmax)

    fontsize = 9 if vmax >= 100 else 10

    for (i,j) in np.ndindex(m.shape):
        t = "" if isnan[i,j] else f"{m[i,j]:.1f}" if vmax < 10.0 else f"{m[i,j]:.0f}"
        c = "w" if m[i,j] < black_at else "k"
        plt.text(j, i, t, ha="center", va="center", color=c, fontsize=fontsize)

    plt.xticks(np.arange(m.shape[1]), labels=[f"{i+1}" for i in range(m.shape[1])], fontsize=9)
    if yticks:
        plt.yticks(np.arange(m.shape[0]), labels=[f"CPU {i+1}" for i in range(m.shape[0])], fontsize=9)
    else:
        plt.yticks([])

    #plt.tight_layout()
    plt.title(f"{title}\n" +
              f"{subtitle}\n" +
              f"Min={vmin:0.1f}ns Median={np.nanmedian(m):0.1f}ns Max={vmax:0.1f}ns",
              fontsize=11, linespacing=1.5)

    plt.savefig(args.outputfile)

cpu = args.core
fname = args.file
m = load_data(fname)

n=args.number

show_heapmap(m[:n,:n], title=f"{cpu}")
EOF
## 生成heatmap.py, 该py脚本用于生成 core-to-core-latency 的热力图 --END
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
yum install -yq lz4-devel lzo-devel libcurl-devel
pip3 install sklearn scons
DOWNLOAD_FILE="ffmpeg-master-latest-linux$([ "$(uname -m)" = "aarch64" ] && echo "arm" || echo "")64-gpl"
DOWNLOAD_URL="https://github.com/BtbN/FFmpeg-Builds/releases/download/latest"
wget ${DOWNLOAD_URL}/${DOWNLOAD_FILE}.tar.xz
tar xf ${DOWNLOAD_FILE}.tar.xz
cp ${DOWNLOAD_FILE}/bin/ffmpeg /usr/local/bin/ && rm -rf ${DOWNLOAD_FILE}*

# 启动一个监控
# DOOL_FILE="${DATA_DIR}/dool.txt"
# dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60 1> ${DOOL_FILE} 2>&1 &

## 执行基准测试(标准)
echo "[INFO] Step1: Start to perform PTS tests ..."

tests="gmpbench primesieve stream cachebench ramspeed compress-zstd compress-lz4 blosc \
  botan john-the-ripper cython-bench ffmpeg x264 x265 tjbench vvenc blogbench nginx \
  graphics-magick smallpt draco renaissance dacapobench java-scimark2 scimark2 \
  redis memtier-benchmark valkey memcached keydb dragonflydb pogocache \
  cassandra scylladb rocksdb influxdb clickhouse duckdb leveldb \
  stockfish mt-dgemm perf-bench mlpack mnn whisper-cpp whisperfile opencv \
  "
for testname in ${tests} 
do
    # 启动一个监控
    DOOL_FILE="${PTS_RESULT_DIR}/${testname}-dool.txt"
    dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 10 > ${DOOL_FILE} 2>&1 &
    DOOL_PID=$!
    # 执行基准测试
    FORCE_TIMES_TO_RUN=3 phoronix-test-suite batch-benchmark ${testname} > ${PTS_RESULT_DIR}/${testname}.txt
    # 保存结果 URL
    echo "${testname}.txt:" >> ${DATA_DIR}/pts-result-url-summary.txt
    grep "Results Uploaded To" ${PTS_RESULT_DIR}/${testname}.txt >> ${DATA_DIR}/pts-result-url-summary.txt
    # 停止监控
    kill -9 ${DOOL_PID}

    sleep 5
done

## 执行时间太长的，设置为只执行 1 次的tests:
tests1="openssl pyperformance cpp-perf-bench c-ray lczero arrayfire hpcg quantlib"
for testname in ${tests1} 
do
    # 启动一个监控
    DOOL_FILE="${PTS_RESULT_DIR}/${testname}-dool.txt"
    dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 10 > ${DOOL_FILE} 2>&1 &
    DOOL_PID=$!
    # 执行基准测试
    FORCE_TIMES_TO_RUN=1 phoronix-test-suite batch-benchmark ${testname} > ${PTS_RESULT_DIR}/${testname}.txt
    # 保存结果 URL
    echo "${testname}.txt:" >> ${DATA_DIR}/pts-result-url-summary.txt
    grep "Results Uploaded To" ${PTS_RESULT_DIR}/${testname}.txt >> ${DATA_DIR}/pts-result-url-summary.txt
    # 停止监控
    kill -9 ${DOOL_PID}
    
    sleep 5
done

## 特殊任务：执行2次的tests。
tests2="scikit-learn"
for testname in ${tests2} 
do
# 启动一个监控
    DOOL_FILE="${PTS_RESULT_DIR}/${testname}-dool.txt"
    dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 10 > ${DOOL_FILE} 2>&1 &
    DOOL_PID=$!
    # 执行基准测试
    FORCE_TIMES_TO_RUN=2 phoronix-test-suite batch-benchmark ${testname} > ${PTS_RESULT_DIR}/${testname}.txt
    # 保存结果 URL
    echo "${testname}.txt:" >> ${DATA_DIR}/pts-result-url-summary.txt
    grep "Results Uploaded To" ${PTS_RESULT_DIR}/${testname}.txt >> ${DATA_DIR}/pts-result-url-summary.txt
    # 停止监控
    kill -9 ${DOOL_PID}
    
    sleep 5
done

echo "[INFO] Step: Complete ALL PTS TESTS."

# 所有结果打包并上传到 S3 bucket
phoronix-test-suite list-installed-tests > ${DATA_DIR}/pts-list-installed-tests.txt
ls -ltr ${PTS_RESULT_DIR} >> ${DATA_DIR}/pts-list-installed-tests.txt
df -h  >> ${DATA_DIR}/pts-list-installed-tests.txt
rm -rf ${LOG_DIR}/*
cp -r /var/log/cloud-init*.log /var/log/phoronix-test-suite-*.log /var/lib/cloud/ /root/userdata.sh ${LOG_DIR}
tar czfP ${DATA_DIR}-all.tar.gz ${DATA_DIR}
aws s3 cp ${DATA_DIR}-all.tar.gz ${aws_s3_bucket_name}/result_pts/ && \
echo "[INFO] Step3: Result files have been uploaded to s3 bucket. BYE BYE."

## Disable 服务，这样 reboot 后不会再次执行
systemctl disable userdata

## 停止实例
INSTANCE_ID=$(ec2-metadata --quiet --instance-id )
aws ec2 stop-instances --instance-ids "${INSTANCE_ID}"
