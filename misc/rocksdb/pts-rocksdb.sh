#!/bin/bash

## Install PTS
INSTALL_PTS_ON_AMAZONLINUX

## 编译 gflags-v2.2.2
yum remove -y gflags-devel
wget https://github.com/gflags/gflags/archive/refs/tags/v2.2.2.tar.gz
tar zxf v2.2.2.tar.gz && cd gflags-2.2.2
mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_CXX_FLAGS="-fPIC" -DCMAKE_C_FLAGS="-fPIC" ..
make && make install

## 安装运行 rocksdb benchmark
phoronix-test-suite install rocksdb
phoronix-test-suite batch-benchmark rocksdb

## 安装运行 influxdb benchmark
phoronix-test-suite install influxdb
phoronix-test-suite batch-benchmark influxdb


############ 公共部分：安装 PTS ############ 
INSTALL_PTS_ON_AMAZONLINUX () {
	OS_NAME=$(egrep ^NAME /etc/os-release | awk -F "\"" '{print $2}')
	OS_VERSION=$(egrep ^VERSION_ID /etc/os-release | awk -F "\"" '{print $2}')
	ARCH=$(arch)

	if [[ "$OS_NAME" == "Amazon Linux" ]]; then
		if [[ "$OS_VERSION" == "2" ]]; then
			install_al2_dependencies
		elif [[ "$OS_VERSION" == "2023" ]]; then
			 install_al2023_dependencies
		else
			 echo "$OS_NAME $OS_VERSION not supported"
			 exit 1
		fi
	elif [[ "$OS_NAME" == "Ubuntu" ]]; then
		install_ubuntu2004_dependencies
	else
		echo "$OS_NAME not supported"
		exit 1
	fi
	
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

	##############################################################################################
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

}
install_al2_dependencies () {
  echo "------ INSTALLING UTILITIES ------"
  yum clean metadata
  yum -y update
  amazon-linux-extras install -y epel
  amazon-linux-extras enable php7.4
  yum install -y -q awscli vim unzip git screen wget p7zip
  yum -y -q groupinstall "Development Tools"
  yum -y -q groupinstall "Development Libraries"
  yum install -y -q  gcc10 gcc10-c++ glibc blas blas-devel openssl-devel libXext-devel libX11-devel libXaw libXaw-devel mesa-libGL-devel 
  yum install -y -q python3 python3-pip python3-devel cargo
  yum install -y -q php php-cli php-json php-xml perl-IPC-Cmd

  echo "------ INSTALLING HIGH LEVEL PERFORMANCE TOOLS ------"
  yum install -y -q sysstat hwloc hwloc-gui util-linux numactl tcpdump htop iotop iftop

  echo "------ INSTALLING LOW LEVEL PERFORAMANCE TOOLS ------"
  amazon-linux-extras enable BCC
  yum install -y -q perf kernel-devel-$(uname -r) bcc

  echo "------ INSTALL ANALYSIS TOOLS AND DEPENDENCIES ------"
  python3 -m pip install --upgrade pip
  python3 -m pip install pandas numpy scipy matplotlib sh seaborn plotext
  git clone https://github.com/brendangregg/FlameGraph.git FlameGraph
  
  echo "------ REPLACE GCC 7.3 WITH GCC 10.X------"
  ## 设置使用 GCC 10.4 版本
  mv /usr/bin/gcc /usr/bin/gcc7.3
  mv /usr/bin/g++ /usr/bin/g++7.3
  alternatives --install /usr/bin/gcc gcc /usr/bin/gcc10-cc  100
  alternatives --install /usr/bin/g++ g++ /usr/bin/gcc10-c++ 100
  gcc --version
  g++ --version

  echo "------ DONE ------"
}
install_al2023_dependencies () {
  echo "------ INSTALLING UTILITIES ------"
  yum clean metadata
  yum -y update
  yum install -y -q dmidecode vim unzip git screen wget p7zip
  yum -y -q groupinstall "Development Tools"
  yum install -y -q glibc blas blas-devel openssl-devel libXext-devel libX11-devel libXaw libXaw-devel mesa-libGL-devel 
  yum install -y -q python3 python3-pip python3-devel cargo
  yum install -y -q php php-cli php-json php-xml perl-IPC-Cmd

  echo "------ INSTALLING HIGH LEVEL PERFORMANCE TOOLS ------"
  yum install -y -q sysstat  hwloc hwloc-gui util-linux numactl tcpdump htop iotop iftop 

  echo "------ INSTALLING LOW LEVEL PERFORAMANCE TOOLS ------"
  yum install -y -q perf kernel-devel-$(uname -r) bcc

  echo "------ INSTALL ANALYSIS TOOLS AND DEPENDENCIES ------"
  python3 -m pip install pandas numpy scipy matplotlib sh seaborn plotext
  git clone https://github.com/brendangregg/FlameGraph.git FlameGraph
  
  echo "------ REINSTALL AWSCLI ------"
  cd /root/
  yum remove -y awscli
  ARCH=$(lscpu | grep Architecture | awk -F " " '{print $NF}')
  curl "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  ./aws/install
  cp -rf /usr/local/bin/aws /usr/bin/aws
  aws --version

  echo "------ DONE ------"
}
install_ubuntu2004_dependencies () {
  echo "------ INSTALLING UTILITIES ------"
  apt update
  apt upgrade
  apt install -y -q build-essential vim unzip git lsb-release grub2-common net-tools dmidecode hwloc util-linux numactl \
    screen wget zip unzip p7zip
  apt install -y -q php php-cli php-json php-xml
  
  apt install -y python3-pip python3-dev cargo libssl-dev libcurl4-openssl-dev libpcap-dev liblzma-dev
  ln -s /usr/sbin/grub-mkconfig /usr/sbin/grub2-mkconfig
  
  ## 更新 GCC 到 10.x
  apt install gcc-10 g++-10 -y
  update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 100 \
    --slave /usr/bin/g++ g++ /usr/bin/g++-10 \
    --slave /usr/bin/gcov gcov /usr/bin/gcov-10
  update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 90 \
    --slave /usr/bin/g++ g++ /usr/bin/g++-9 \
    --slave /usr/bin/gcov gcov /usr/bin/gcov-9
  
  echo "------ INSTALLING HIGH LEVEL PERFORMANCE TOOLS ------"
  apt install -y -q sysstat hwloc tcpdump dstat htop iotop iftop nload mytop stress-ng 

  echo "------ INSTALLING LOW LEVEL PERFORAMANCE TOOLS ------"
  apt install -y -q linux-tools-$(uname -r) linux-headers-$(uname -r) linux-modules-extra-$(uname -r) bpfcc-tools

  echo "------ INSTALL ANALYSIS TOOLS AND DEPENDENCIES ------"
  python3 -m pip install --upgrade pip
  python3 -m pip install pandas numpy scipy matplotlib sh seaborn plotext 
  git clone https://github.com/brendangregg/FlameGraph.git FlameGraph

  echo "------ DONE ------"
}