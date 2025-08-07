#!/bin/bash

# Native Libraries Build Script for x86_64 architecture

set -e

echo "Building native libraries for x86_64..."

# 设置环境变量
export JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/java-11-openjdk-amd64}
export ARCH=x86_64

# 创建输出目录
mkdir -p target/native/linux-x86_64
mkdir -p src/main/resources/native/linux-x86_64

# 编译器设置
CC=gcc
CXX=g++
CFLAGS="-fPIC -O2 -Wall"
CXXFLAGS="-fPIC -O2 -Wall -std=c++11"
INCLUDES="-I${JAVA_HOME}/include -I${JAVA_HOME}/include/linux"
LDFLAGS="-shared"

# 构建 mathutils.so
echo "Building libmathutils.so..."
${CXX} ${CXXFLAGS} ${INCLUDES} ${LDFLAGS} \
    -o target/native/linux-x86_64/libmathutils.so \
    src/main/cpp/mathutils.cpp

# 构建 stringutils.so
echo "Building libstringutils.so..."
${CXX} ${CXXFLAGS} ${INCLUDES} ${LDFLAGS} \
    -o target/native/linux-x86_64/libstringutils.so \
    src/main/cpp/stringutils.cpp

# 构建 systeminfo.so
echo "Building libsysteminfo.so..."
${CXX} ${CXXFLAGS} ${INCLUDES} ${LDFLAGS} \
    -o target/native/linux-x86_64/libsysteminfo.so \
    src/main/cpp/systeminfo.cpp

# 复制到 resources 目录
cp target/native/linux-x86_64/*.so src/main/resources/native/linux-x86_64/

# 验证构建结果
echo "Verifying built libraries..."
for lib in mathutils stringutils systeminfo; do
    if [ -f "target/native/linux-x86_64/lib${lib}.so" ]; then
        echo "✓ lib${lib}.so built successfully"
        file "target/native/linux-x86_64/lib${lib}.so"
    else
        echo "✗ lib${lib}.so build failed"
        exit 1
    fi
done

echo "Native libraries build completed successfully!"
