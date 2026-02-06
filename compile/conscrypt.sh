#!/bin/bash

# amazon linux 2023, c8g.xlarge 实例

# 安装开发工具包
sudo yum groupinstall "Development Tools" -yq
sudo yum install -y git maven java-17-amazon-corretto-devel

# # 下载最新版本的 Gradle
# GRADLE_VERSION=8.5
# wget https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip
# sudo unzip -d /opt gradle-${GRADLE_VERSION}-bin.zip
# sudo ln -s /opt/gradle-${GRADLE_VERSION} /opt/gradle
# echo 'export GRADLE_HOME=/opt/gradle' | sudo tee -a /etc/profile.d/gradle.sh
# echo 'export PATH=$GRADLE_HOME/bin:$PATH' | sudo tee -a /etc/profile.d/gradle.sh
# sudo chmod +x /etc/profile.d/gradle.sh
# source /etc/profile.d/gradle.sh
# gradle --version

#######################################################################
# 安装 BoringSSL
cd /root/
yum install -y cmake ninjia-build
git clone https://boringssl.googlesource.com/boringssl
cd boringssl
mkdir build64 && cd build64
cmake -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_ASM_FLAGS=-Wa,--noexecstack \
      -GNinja ..
ninja
export BORINGSSL_HOME=/root/boringssl/

#######################################################################
# 安装 Conscrypt 2.5.2 (Failed)
cd /root/
wget https://github.com/google/conscrypt/archive/refs/tags/2.5.2.tar.gz
tar -xzf 2.5.2.tar.gz
cd conscrypt-2.5.2

#######################################################################
# 安装 Conscrypt master 分支 (Failed)
cd /root/
git clone https://github.com/google/conscrypt.git
cd conscrypt
./gradlew build

# (base) [root@ip-172-31-73-75 conscrypt]# ./gradlew build
# Android SDK has not been detected. Skipping Android projects.

# FAILURE: Build failed with an exception.

# * Where:
# Build file '/root/conscrypt/openjdk/build.gradle' line: 128

# * What went wrong:
# A problem occurred evaluating project ':conscrypt-openjdk'.
# > No test build selected for os.arch = aarch_64. Expression: (buildToTest != null). Values: buildToTest = null

# * Try:
# > Run with --stacktrace option to get the stack trace.
# > Run with --info or --debug option to get more log output.
# > Run with --scan to get full insights.

# * Get more help at https://help.gradle.org

# BUILD FAILED in 663ms
# 9 actionable tasks: 9 up-to-date
