#!/bin/bash

# Cross-compilation script for building ARM64 binaries on x86_64
# 在 x86_64 系统上交叉编译 ARM64 版本

set -e

echo "========================================="
echo "Cross-compiling ARM64 libraries on x86_64"
echo "在 x86_64 系统上交叉编译 ARM64 库"
echo "========================================="

# 检查当前架构
CURRENT_ARCH=$(uname -m)
if [ "$CURRENT_ARCH" != "x86_64" ]; then
    echo "❌ 此脚本仅适用于 x86_64 系统"
    echo "当前架构: $CURRENT_ARCH"
    exit 1
fi

# 检查交叉编译工具链
echo "检查 ARM64 交叉编译工具链..."
if ! command -v aarch64-linux-gnu-gcc &> /dev/null; then
    echo "❌ 未找到 ARM64 交叉编译工具链"
    echo ""
    echo "请安装交叉编译工具链:"
    echo "  Ubuntu/Debian:"
    echo "    sudo apt-get update"
    echo "    sudo apt-get install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu"
    echo ""
    echo "  或者运行自动安装:"
    read -p "是否自动安装交叉编译工具链? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "正在安装交叉编译工具链..."
        sudo apt-get update
        sudo apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
    else
        echo "跳过安装，退出脚本"
        exit 1
    fi
fi

# 验证工具链
echo "✓ ARM64 交叉编译工具链可用:"
aarch64-linux-gnu-gcc --version | head -1 | sed 's/^/  /'
aarch64-linux-gnu-g++ --version | head -1 | sed 's/^/  /'

# 设置交叉编译环境变量
export CC=aarch64-linux-gnu-gcc
export CXX=aarch64-linux-gnu-g++
export TARGET_ARCH=aarch64

# 设置 JAVA_HOME（使用 x86_64 版本的 JDK 头文件）
if [ -z "$JAVA_HOME" ]; then
    if [ -d "/usr/lib/jvm/java-11-openjdk-amd64" ]; then
        export JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
    elif [ -d "/usr/lib/jvm/default-java" ]; then
        export JAVA_HOME="/usr/lib/jvm/default-java"
    else
        echo "❌ 未找到 JAVA_HOME"
        echo "请安装 OpenJDK 11 开发包: sudo apt-get install openjdk-11-jdk"
        exit 1
    fi
fi

echo "使用 JAVA_HOME: $JAVA_HOME"
echo "交叉编译目标架构: $TARGET_ARCH"

# 创建输出目录
mkdir -p target/native/linux-aarch64
mkdir -p src/main/resources/native/linux-aarch64

# 编译器设置
CFLAGS="-fPIC -O2 -Wall -march=armv8-a"
CXXFLAGS="-fPIC -O2 -Wall -std=c++11 -march=armv8-a"
INCLUDES="-I${JAVA_HOME}/include -I${JAVA_HOME}/include/linux"
LDFLAGS="-shared"

echo ""
echo "开始交叉编译 ARM64 native libraries..."

# 构建 mathutils.so
echo "Cross-compiling libmathutils.so for ARM64..."
${CXX} ${CXXFLAGS} ${INCLUDES} ${LDFLAGS} \
    -o target/native/linux-aarch64/libmathutils.so \
    src/main/cpp/mathutils.cpp

# 构建 stringutils.so
echo "Cross-compiling libstringutils.so for ARM64..."
${CXX} ${CXXFLAGS} ${INCLUDES} ${LDFLAGS} \
    -o target/native/linux-aarch64/libstringutils.so \
    src/main/cpp/stringutils.cpp

# 构建 systeminfo.so
echo "Cross-compiling libsysteminfo.so for ARM64..."
${CXX} ${CXXFLAGS} ${INCLUDES} ${LDFLAGS} \
    -o target/native/linux-aarch64/libsysteminfo.so \
    src/main/cpp/systeminfo.cpp

# 复制到 resources 目录
cp target/native/linux-aarch64/*.so src/main/resources/native/linux-aarch64/

echo ""
echo "验证交叉编译结果..."
for lib in mathutils stringutils systeminfo; do
    lib_file="target/native/linux-aarch64/lib${lib}.so"
    if [ -f "$lib_file" ]; then
        echo "✓ lib${lib}.so 交叉编译成功"
        file_info=$(file "$lib_file")
        echo "  $file_info"
        
        # 验证架构
        if echo "$file_info" | grep -q "ARM aarch64"; then
            echo "  ✓ 架构验证通过: ARM64"
        else
            echo "  ❌ 架构验证失败: 不是 ARM64"
            exit 1
        fi
        
        # 检查 ELF 头信息
        echo "  架构详情:"
        readelf -h "$lib_file" | grep Machine | sed 's/^/    /'
    else
        echo "❌ lib${lib}.so 交叉编译失败"
        exit 1
    fi
done

echo ""
echo "========================================="
echo "✅ ARM64 交叉编译完成!"
echo "========================================="
echo ""
echo "ARM64 native libraries 已生成:"
echo "  target/native/linux-aarch64/"
echo "  src/main/resources/native/linux-aarch64/"
echo ""
echo "下一步:"
echo "  1. 运行 'mvn compile package' 构建包含 ARM64 支持的 JAR"
echo "  2. 或者运行 './build.sh' 进行完整构建"
echo ""
echo "生成的 JAR 包可以在 ARM64 系统上运行"
