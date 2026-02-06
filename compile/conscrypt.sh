#!/bin/bash

# amazon linux 2023, c8g.xlarge 实例

# 安装开发工具包
sudo yum groupinstall "Development Tools" -yq
sudo yum install -y git maven java-17-amazon-corretto-devel

# 下载最新版本的 Gradle
GRADLE_VERSION=8.5
wget https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip
sudo unzip -d /opt gradle-${GRADLE_VERSION}-bin.zip
sudo ln -s /opt/gradle-${GRADLE_VERSION} /opt/gradle
echo 'export GRADLE_HOME=/opt/gradle' | sudo tee -a /etc/profile.d/gradle.sh
echo 'export PATH=$GRADLE_HOME/bin:$PATH' | sudo tee -a /etc/profile.d/gradle.sh
sudo chmod +x /etc/profile.d/gradle.sh
source /etc/profile.d/gradle.sh
gradle --version


#######################################################################
# 安装BoringSSL
yum install -y cmake ninjia-build
git clone https://boringssl.googlesource.com/boringssl
cd boringssl
mkdir build64 && cd build64
cmake -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_ASM_FLAGS=-Wa,--noexecstack \
      -GNinja ..
ninja
sudo cp *.a /usr/local/lib/


#######################################################################
# 安装 Conscrypt
wget https://github.com/google/conscrypt/archive/refs/tags/2.5.2.tar.gz
tar -xzf 2.5.2.tar.gz
cd conscrypt-2.5.2

