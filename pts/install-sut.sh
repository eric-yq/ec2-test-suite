#!/bin/bash

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
aws_region_name=$(ec2-metadata --quiet --region)
aws configure set aws_access_key_id ${aws_ak_value}
aws configure set aws_secret_access_key ${aws_sk_value}
aws configure set default.region ${aws_region_name}
aws_s3_bucket_name=$(aws s3 ls | awk '{print $3}' | grep ec2-core-benchmark | head -1)

# 主要流程
install_al2023_dependencies

# 如果有本地 SSD 盘，则设置磁盘lvm stripe，会自动挂载在 /data 目录。
cd /root/
git clone https://github.com/eric-yq/ec2-test-suite.git
bash ec2-test-suite/tools/setup_nvme_instance_store.sh
# 创建一个 /data 目录，如果没有本地 SSD 盘，上一步不会创建 /data 目录。
mkdir -p /data

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
mkdir -p ${DATA_DIR} ${CFG_DIR} ${PTS_RESULT_DIR} ${LOG_DIR} 

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
## 设置测试项安装在 /data/ 目录下（可以是 EBS 或者 本地 SSD 盘)
echo "export PTS_DOWNLOAD_CACHE=/data/" >> /root/.bashrc
echo "export PTS_TEST_INSTALL_ROOT_PATH=/data/" >> /root/.bashrc
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
## 安装 Phoronix
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
wget ${DOWNLOAD_URL}/${DOWNLOAD_FILE}.tar.xz && tar xf ${DOWNLOAD_FILE}.tar.xz
cp ${DOWNLOAD_FILE}/bin/ffmpeg /usr/local/bin/ && rm -rf ${DOWNLOAD_FILE}*

# 安装 sysbench
cd /root/
rpm -Uvh https://repo.mysql.com//mysql80-community-release-el9.rpm
yum install -y mysql-devel --nogpgcheck
wget https://github.com/akopytov/sysbench/archive/refs/tags/1.0.20.tar.gz
tar zxf 1.0.20.tar.gz && rm -rf 1.0.20.tar.gz && cd sysbench-1.0.20
./autogen.sh && ./configure --with-mysql && make -j && make install && sysbench --version

# 创建 python3.11 的 venv 环境
yum install -yq python3.11*
VENV=/root/venv-py311
[ -d "$VENV" ] || python3.11 -m venv "$VENV"
echo "export VENV=/root/venv-py311" >> /root/.bashrc
source /root/.bashrc

########################################################################################################
## 执行基准测试(标准)
echo "[INFO] Step1: Start to perform PTS tests ..."

tests="stream cachebench ramspeed compress-zstd compress-lz4 blosc \
  botan john-the-ripper cython-bench ffmpeg x264 x265 tjbench vvenc svt-av1 blogbench nginx \
  graphics-magick smallpt draco renaissance dacapobench java-scimark2 scimark2 libxsmm faiss \
  redis memtier-benchmark valkey dragonflydb pogocache tidb sonicjson simdjson \
  cassandra scylladb mariadb rocksdb influxdb clickhouse duckdb leveldb cockroach couchdb spark \
  c-ray lczero arrayfire stockfish mt-dgemm perf-bench mlpack mnn whisper-cpp whisperfile opencv \
  "
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

## 执行时间太长的，设置为只执行 1 次的tests:
tests1="openssl hpcg quantlib"
for testname in ${tests1} 
do
    # 启动一个监控
    DOOL_FILE="${PTS_RESULT_DIR}/${testname}-dool.txt"
    dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60 > ${DOOL_FILE} 2>&1 &
    DOOL_PID=$!
    # 执行基准测试
    FORCE_TIMES_TO_RUN=1 phoronix-test-suite batch-benchmark ${testname} > ${PTS_RESULT_DIR}/${testname}.txt
    # 保存结果 URL
    echo "${testname}:" >> ${DATA_DIR}/test-report-url-summary.txt
    phoronix-test-suite info ${testname} | grep "Description: "  >> ${DATA_DIR}/test-report-url-summary.txt
    grep "Results Uploaded To" ${PTS_RESULT_DIR}/${testname}.txt >> ${DATA_DIR}/test-report-url-summary.txt
    # 停止监控
    kill -9 ${DOOL_PID}

    sleep 5
done

################################################################################################
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

################################################################################################
# spark-tpcds: 只测试 PRESET_OPTIONS_VALUES='spark-tpcds.scale=500'
testname="spark-tpcds"
# 启动一个监控
DOOL_FILE="${PTS_RESULT_DIR}/${testname}-dool.txt"
dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 30 > ${DOOL_FILE} 2>&1 &
DOOL_PID=$!
# 执行基准测试: spark-tpcds 需要使用 gcc11.
yes | PRESET_OPTIONS_VALUES="${testname}.scale=500" FORCE_TIMES_TO_RUN=1 CC=gcc CXX=g++ \
  phoronix-test-suite benchmark ${testname} > ${PTS_RESULT_DIR}/${testname}.txt
# 保存结果 URL
echo "${testname}:" >> ${DATA_DIR}/test-report-url-summary.txt
phoronix-test-suite info ${testname} | grep "Description: "  >> ${DATA_DIR}/test-report-url-summary.txt
grep "Results Uploaded To" ${PTS_RESULT_DIR}/${testname}.txt >> ${DATA_DIR}/test-report-url-summary.txt
# 停止监控
kill -9 ${DOOL_PID}
sleep 5

################################################################################################
# spark-tpch:只测试 PRESET_OPTIONS_VALUES='spark-tpch.scale=10,100'
testname="spark-tpch"
# 启动一个监控
DOOL_FILE="${PTS_RESULT_DIR}/${testname}-dool.txt"
dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 30 > ${DOOL_FILE} 2>&1 &
DOOL_PID=$!
# 执行基准测试
yes | PRESET_OPTIONS_VALUES="${testname}.scale=10,100,500" FORCE_TIMES_TO_RUN=3 \
  phoronix-test-suite benchmark ${testname} > ${PTS_RESULT_DIR}/${testname}.txt
# 保存结果 URL
echo "${testname}:" >> ${DATA_DIR}/test-report-url-summary.txt
phoronix-test-suite info ${testname} | grep "Description: "  >> ${DATA_DIR}/test-report-url-summary.txt
grep "Results Uploaded To" ${PTS_RESULT_DIR}/${testname}.txt >> ${DATA_DIR}/test-report-url-summary.txt
# 停止监控
kill -9 ${DOOL_PID}
sleep 5

## qdrant 需要使用 python 3.10 以上
testname="qdrant"
# 进入 python 3.11虚拟环境
source "$VENV/bin/activate"
phoronix-test-suite info pts/qdrant-1.0.0

# 修改安装脚本
PROFILE_DIR=/var/lib/phoronix-test-suite/test-profiles/pts/qdrant-1.0.0
cd "$PROFILE_DIR"
[ -f install.sh.orig ] || cp install.sh install.sh.orig       # 只在第一次备份原始脚本
sed -i -e 's/ --user//g' \
       -e 's#/usr/bin/python3#python3#g' \
       -e 's#/usr/bin/pip3#pip3#g' \
       -e 's#\$HOME/\.local/bin/##g' \
       -e 's#~/\.local/bin/##g' install.sh
echo "---- 修改内容 ----"
diff install.sh.orig install.sh || true

# 安装
phoronix-test-suite install pts/qdrant-1.0.0
# 修改测试脚本
INSTALL_DIR=/data/pts/qdrant-1.0.0
cd "$INSTALL_DIR"
cp -n qdrant qdrant.orig
head -1 qdrant.orig > qdrant
cat >> qdrant << 'EOF'
# 清掉上一轮残留的进程和数据
pkill -f qdrant-bin 2>/dev/null
while pgrep -f qdrant-bin >/dev/null; do sleep 1; done
rm -rf ./storage ./snapshots

./qdrant-bin --disable-telemetry &
QDRANT_PID=$!
# 等 Qdrant 就绪，最多 120 秒
for i in $(seq 1 120); do
  curl -sf http://localhost:6333/readyz >/dev/null && break
  sleep 1
done

vectordbbench qdrantlocal --load-concurrency 1 $@ > $LOG_FILE

# 停止并等进程真正退出
kill $QDRANT_PID
wait $QDRANT_PID 2>/dev/null
rm -rf ./storage ./snapshots
EOF
chmod +x qdrant
# cat qdrant

# 启动一个监控
DOOL_FILE="${PTS_RESULT_DIR}/${testname}-dool.txt"
dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60 > ${DOOL_FILE} 2>&1 &
DOOL_PID=$!

# 执行基准测试
phoronix-test-suite batch-benchmark ${testname} > ${PTS_RESULT_DIR}/${testname}.txt
# 保存结果 URL
echo "${testname}:" >> ${DATA_DIR}/test-report-url-summary.txt
phoronix-test-suite info ${testname} | grep "Description: "  >> ${DATA_DIR}/test-report-url-summary.txt
grep "Results Uploaded To" ${PTS_RESULT_DIR}/${testname}.txt >> ${DATA_DIR}/test-report-url-summary.txt
# 停止监控
kill -9 ${DOOL_PID}
# 退出python 3.11 虚拟环境
deactivate
sleep 5

################################################################################################
## pgvector 需要使用 python 3.10 以上
testname="pgvector"
# 进入 python 3.11虚拟环境
source "$VENV/bin/activate"
pip install "psycopg[binary]"
phoronix-test-suite info pts/pgvector-1.0.0 

# 修改安装脚本
PROFILE_DIR=/var/lib/phoronix-test-suite/test-profiles/pts/pgvector-1.0.0
INSTALL_DIR=/data/pts/pgvector-1.0.0
cd "$PROFILE_DIR"
[ -f install.sh.orig ] || cp install.sh install.sh.orig
sed -i -E '/pip/ s/ --user( |$)/\1/g' install.sh
diff install.sh.orig install.sh || true    # 应该只有 pip 那一行有变化

# 安装
phoronix-test-suite install pts/pgvector-1.0.0
mkdir -p $INSTALL_DIR/.local/bin/
cp $VENV/bin/vectordbbench $INSTALL_DIR/.local/bin/
# 修改运行脚本：createdb/createuser 已存在时跳过
cd "$INSTALL_DIR"
cp -n pgvector pgvector.orig
sed -i -e 's|^pg_/bin/createdb vectordbbench.*|pg_/bin/createdb vectordbbench 2>/dev/null \|\| true|' \
       -e 's|^pg_/bin/createuser postgresuser.*|pg_/bin/createuser postgresuser -d -s --no-password 2>/dev/null \|\| true|' pgvector
grep -n -E "createdb|createuser" pgvector    # 两行末尾都应有 || true

# 启动一个监控
DOOL_FILE="${PTS_RESULT_DIR}/${testname}-dool.txt"
dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60 > ${DOOL_FILE} 2>&1 &
DOOL_PID=$!

# 执行基准测试
phoronix-test-suite batch-benchmark ${testname} > ${PTS_RESULT_DIR}/${testname}.txt
# 保存结果 URL
echo "${testname}:" >> ${DATA_DIR}/test-report-url-summary.txt
phoronix-test-suite info ${testname} | grep "Description: "  >> ${DATA_DIR}/test-report-url-summary.txt
grep "Results Uploaded To" ${PTS_RESULT_DIR}/${testname}.txt >> ${DATA_DIR}/test-report-url-summary.txt
# 停止监控
kill -9 ${DOOL_PID}
# 退出python 3.11 虚拟环境
deactivate
sleep 5

##############################################################################################################
echo "[INFO] Step: Complete ALL PTS TESTS."

# 所有结果打包并上传到 S3 bucket
phoronix-test-suite list-installed-tests > ${DATA_DIR}/pts-list-installed-tests.txt
ls -ltr ${PTS_RESULT_DIR} >> ${DATA_DIR}/pts-list-installed-tests.txt
df -h  >> ${DATA_DIR}/pts-list-installed-tests.txt
rm -rf ${LOG_DIR}/*
cp -r /var/log/cloud-init*.log /var/log/phoronix-test-suite-*.log /var/lib/cloud/ /root/userdata.sh ${LOG_DIR}
tar czfP ${DATA_DIR}-all.tar.gz ${DATA_DIR}
aws_s3_bucket_name=$(aws s3 ls | awk '{print $3}' | grep ec2-core-benchmark | head -1)
aws s3 cp ${DATA_DIR}-all.tar.gz s3://${aws_s3_bucket_name}/result_pts/ && \
echo "[INFO] Step3: Result files have been uploaded to s3 bucket. BYE BYE."

## Disable 服务，这样 reboot 后不会再次执行
systemctl disable userdata.service

## 停止实例
INSTANCE_ID=$(ec2-metadata --quiet --instance-id )
aws ec2 stop-instances --instance-ids "${INSTANCE_ID}"
