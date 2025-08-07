#!/bin/bash

# Native Libraries Build Script for Multi-Architecture Support

set -e

echo "Building native libraries..."

# 检测架构
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        TARGET_ARCH="x86_64"
        JAVA_HOME_DEFAULT="/usr/lib/jvm/java-11-openjdk-amd64"
        MARCH_FLAG="-march=x86-64"
        ;;
    aarch64|arm64)
        TARGET_ARCH="aarch64"
        JAVA_HOME_DEFAULT="/usr/lib/jvm/java-11-openjdk-arm64"
        MARCH_FLAG="-march=armv8-a"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# 设置环境变量
export JAVA_HOME=${JAVA_HOME:-$JAVA_HOME_DEFAULT}
export TARGET_ARCH

echo "Building for architecture: $TARGET_ARCH"
echo "Using JAVA_HOME: $JAVA_HOME"

# 检查 JAVA_HOME 是否存在
if [ ! -d "$JAVA_HOME" ]; then
    echo "Warning: $JAVA_HOME not found, trying alternative paths..."
    if [ -d "/usr/lib/jvm/default-java" ]; then
        export JAVA_HOME="/usr/lib/jvm/default-java"
        echo "Using alternative JAVA_HOME: $JAVA_HOME"
    else
        echo "Error: Cannot find valid JAVA_HOME"
        exit 1
    fi
fi

# 创建输出目录
mkdir -p target/native/linux-$TARGET_ARCH
mkdir -p src/main/resources/native/linux-$TARGET_ARCH

# 编译器设置
CC=${CC:-gcc}
CXX=${CXX:-g++}
CFLAGS="-fPIC -O2 -Wall $MARCH_FLAG"
CXXFLAGS="-fPIC -O2 -Wall -std=c++11 $MARCH_FLAG"
INCLUDES="-I${JAVA_HOME}/include -I${JAVA_HOME}/include/linux"
LDFLAGS="-shared"

echo "Compiler: $CXX"
echo "Flags: $CXXFLAGS"

# 构建 mathutils.so
echo "Building libmathutils.so for $TARGET_ARCH..."
${CXX} ${CXXFLAGS} ${INCLUDES} ${LDFLAGS} \
    -o target/native/linux-$TARGET_ARCH/libmathutils.so \
    src/main/cpp/mathutils.cpp

# 构建 stringutils.so
echo "Building libstringutils.so for $TARGET_ARCH..."
${CXX} ${CXXFLAGS} ${INCLUDES} ${LDFLAGS} \
    -o target/native/linux-$TARGET_ARCH/libstringutils.so \
    src/main/cpp/stringutils.cpp

# 构建 systeminfo.so
echo "Building libsysteminfo.so for $TARGET_ARCH..."
${CXX} ${CXXFLAGS} ${INCLUDES} ${LDFLAGS} \
    -o target/native/linux-$TARGET_ARCH/libsysteminfo.so \
    src/main/cpp/systeminfo.cpp

# 复制到 resources 目录
cp target/native/linux-$TARGET_ARCH/*.so src/main/resources/native/linux-$TARGET_ARCH/

# 验证构建结果
echo "Verifying built libraries for $TARGET_ARCH..."
for lib in mathutils stringutils systeminfo; do
    lib_file="target/native/linux-$TARGET_ARCH/lib${lib}.so"
    if [ -f "$lib_file" ]; then
        echo "✓ lib${lib}.so built successfully"
        file "$lib_file"
        echo "  Dependencies:"
        ldd "$lib_file" 2>/dev/null || echo "  (ldd not available or library not found)"
    else
        echo "✗ lib${lib}.so build failed"
        exit 1
    fi
done

echo "Native libraries build completed successfully for $TARGET_ARCH!"
