# r8gd.metal-24xl, 96c, 768g, 3*1900GB NVME SSD
# Ubuntu 24.04


# 格式化磁盘，nvme1n1p1 挂在 /mnt/dev/nvme1n1p1
disks=$(lsblk |grep disk | grep -v nvme0 | grep -v xvda | sort | awk -F " " '{print $1}')
for disk in $disks
do
    echo "[INFO] Start to create partition on $disk..."
    echo -e "g\nn\n1\n\n\nw" | fdisk /dev/$disk

    echo "[INFO] Start to create filesystem on $device..."
    partition=${disk}p1 && mkdir -p /data/$partition
    device="/dev/$partition" && mkfs -t xfs -f $device

    echo "[INFO] Start to modify /etc/fstab..."
    uuid=$(blkid | grep $partition | awk -F "\"" '{print $2}')
    echo "UUID=$uuid /data/$partition xfs  defaults,discard  0  2" >> /etc/fstab
done
mount -a && df -h

# 安装 AWSCLI
apt update
apt install -y unzip
ARCH=$(arch)
curl "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
cp -rf /usr/local/bin/aws /usr/bin/aws
aws --version 

aws_ak_value="akxxx"
aws_sk_value="skxxx"
aws_region_name="us-west-2"
aws_s3_bucket_name="s3://ec2-core-benchmark-ericyq"
aws configure set aws_access_key_id ${aws_ak_value}
aws configure set aws_secret_access_key ${aws_sk_value}
aws configure set default.region ${aws_region_name}
aws s3 ls

## 依赖关系
apt update
apt -y upgrade
apt install -y dmidecode vim unzip git screen wget p7zip-full
apt install -y build-essential
apt install -y libc6-dev libblas-dev libblas3 libssl-dev libxext-dev libx11-dev libxaw7-dev libgl1-mesa-dev
apt install -y python3 python3-pip python3-dev cargo
apt install -y php php-cli php-json php-xml libperl-dev
apt install -y sysstat hwloc hwloc-nox util-linux numactl tcpdump htop iotop iftop

# 更新 cmake
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

# PTS 测试用例安装在 /var/lib/phoronix-test-suite 目录下
mkdir -p /data/nvme1n1p1/var-lib-phoronix-test-suite/
ln -s /data/nvme1n1p1/var-lib-phoronix-test-suite/ /var/lib/phoronix-test-suite

##############################################################################################
## PTS（Phoronix-Test-Suite）基准测试
## 安装依赖包
cd ~
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

# 简单测试
phoronix-test-suite benchmark stream



###########################################################################################
# 测试集1：2411074-NE-MERGE254331
# 参考：AMD EPYC 9005 Turin vs. NVIDIA GH200 Grace CPU Performance Benchmarks
# https://www.phoronix.com/review/nvidia-grace-epyc-turin
# https://openbenchmarking.org/result/2411074-NE-MERGE254331&sgm=1&scalar=1&sppt=1&sor

# 安装本次测试集所需的一些特定依赖包
apt install -y pkg-config libevent-dev libssl-dev autotools-dev autoconf automake \
  libreadline-dev libscotch-dev libptscotch-dev libuv1-dev cmake build-essential
apt install -y libtool m4 gettext libncurses5-dev libncursesw5-dev zlib1g-dev libffi-dev \
  libgmp-dev libmpfr-dev libmpc-dev

# 安装测试集
phoronix-test-suite install 2411074-NE-MERGE254331

# 执行测试集
phoronixt-test-suite benchmark 2411074-NE-MERGE254331


###########################################################################################
# 测试集2：2402085-NE-2402073NE50
# 参考：NVIDIA GH200 CPU Performance Benchmarks Against AMD EPYC Zen 4 & Intel Xeon Emerald Rapids
# https://www.phoronix.com/review/nvidia-gh200-gptshop-benchmark 
# https://openbenchmarking.org/result/2402085-NE-2402073NE50&sor&sgm

# 安装本次测试集所需的一些特定依赖包
# 在测试集 1 的基础上，无需安装其他依赖包。

# 安装测试集
phoronix-test-suite install 2402085-NE-2402073NE50

# 执行测试集
phoronixt-test-suite benchmark 2402085-NE-2402073NE50


###########################################################################################
## CPU STREAM
# 安装docker
apt install -y docker.io
systemctl enable docker
systemctl start docker


