#!/bin/bash

# Complete Build Script for Multi-Architecture Support
# 构建包含 x86_64 和 ARM64 两种架构的通用 JAR 包

set -e

echo "========================================="
echo "Java Native Demo Multi-Architecture Build"
echo "构建支持 x86_64 和 ARM64 的通用 JAR 包"
echo "========================================="

# 检测当前系统架构
CURRENT_ARCH=$(uname -m)
echo "当前构建系统架构: $CURRENT_ARCH"

# 设置 Java 环境
if [ -z "$JAVA_HOME" ]; then
    echo "JAVA_HOME is not set. Trying to detect..."
    if [ -d "/usr/lib/jvm/java-11-openjdk-amd64" ]; then
        export JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
        echo "Set JAVA_HOME to: $JAVA_HOME"
    elif [ -d "/usr/lib/jvm/java-11-openjdk-arm64" ]; then
        export JAVA_HOME="/usr/lib/jvm/java-11-openjdk-arm64"
        echo "Set JAVA_HOME to: $JAVA_HOME"
    elif [ -d "/usr/lib/jvm/default-java" ]; then
        export JAVA_HOME="/usr/lib/jvm/default-java"
        echo "Set JAVA_HOME to: $JAVA_HOME"
    else
        echo "Error: JAVA_HOME not found. Please install OpenJDK 11 or set JAVA_HOME manually."
        exit 1
    fi
fi

# 检查必要的工具
echo "Checking build tools..."
for tool in gcc g++ mvn; do
    if ! command -v $tool &> /dev/null; then
        echo "Error: $tool is not installed"
        echo "Please install build tools: sudo apt-get install gcc g++ maven"
        exit 1
    else
        echo "✓ $tool found"
    fi
done

# 显示编译器信息
echo "Compiler information:"
gcc --version | head -1
g++ --version | head -1

# 清理之前的构建
echo "Cleaning previous build..."
mvn clean
rm -rf target/native/

echo ""
echo "========================================="
echo "Step 1: 构建当前架构的 Native Libraries"
echo "========================================="

# 构建当前架构的 native libraries
./build-native.sh

echo ""
echo "========================================="
echo "Step 2: 构建其他架构的 Native Libraries"
echo "========================================="

case $CURRENT_ARCH in
    x86_64)
        echo "当前在 x86_64 系统上，尝试交叉编译 ARM64 版本..."
        
        # 检查是否有交叉编译工具链
        if command -v aarch64-linux-gnu-gcc &> /dev/null; then
            echo "✓ 发现 ARM64 交叉编译工具链，开始交叉编译..."
            ./build-cross-compile.sh
        else
            echo "⚠️  未找到 ARM64 交叉编译工具链"
            echo "安装交叉编译工具链: sudo apt-get install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu"
            echo "跳过 ARM64 编译，仅构建 x86_64 版本"
        fi
        ;;
    aarch64|arm64)
        echo "当前在 ARM64 系统上，尝试交叉编译 x86_64 版本..."
        
        # 检查是否有交叉编译工具链
        if command -v x86_64-linux-gnu-gcc &> /dev/null; then
            echo "✓ 发现 x86_64 交叉编译工具链，开始交叉编译..."
            # 创建 x86_64 交叉编译脚本调用
            export CC=x86_64-linux-gnu-gcc
            export CXX=x86_64-linux-gnu-g++
            export TARGET_ARCH=x86_64
            
            mkdir -p target/native/linux-x86_64
            mkdir -p src/main/resources/native/linux-x86_64
            
            # 使用 x86_64 特定的编译标志
            CFLAGS="-fPIC -O2 -Wall -march=x86-64"
            CXXFLAGS="-fPIC -O2 -Wall -std=c++11 -march=x86-64"
            INCLUDES="-I${JAVA_HOME}/include -I${JAVA_HOME}/include/linux"
            LDFLAGS="-shared"
            
            echo "Cross-compiling libmathutils.so for x86_64..."
            ${CXX} ${CXXFLAGS} ${INCLUDES} ${LDFLAGS} \
                -o target/native/linux-x86_64/libmathutils.so \
                src/main/cpp/mathutils.cpp
            
            echo "Cross-compiling libstringutils.so for x86_64..."
            ${CXX} ${CXXFLAGS} ${INCLUDES} ${LDFLAGS} \
                -o target/native/linux-x86_64/libstringutils.so \
                src/main/cpp/stringutils.cpp
            
            echo "Cross-compiling libsysteminfo.so for x86_64..."
            ${CXX} ${CXXFLAGS} ${INCLUDES} ${LDFLAGS} \
                -o target/native/linux-x86_64/libsysteminfo.so \
                src/main/cpp/systeminfo.cpp
            
            cp target/native/linux-x86_64/*.so src/main/resources/native/linux-x86_64/
            echo "✓ x86_64 交叉编译完成"
        else
            echo "⚠️  未找到 x86_64 交叉编译工具链"
            echo "安装交叉编译工具链: sudo apt-get install gcc-x86-64-linux-gnu g++-x86-64-linux-gnu"
            echo "跳过 x86_64 编译，仅构建 ARM64 版本"
        fi
        ;;
    *)
        echo "⚠️  不支持的架构: $CURRENT_ARCH"
        echo "仅构建当前架构版本"
        ;;
esac

echo ""
echo "========================================="
echo "Step 3: 验证 Native Libraries"
echo "========================================="

echo "检查已构建的 native libraries:"
for arch_dir in target/native/linux-*; do
    if [ -d "$arch_dir" ]; then
        arch_name=$(basename "$arch_dir" | sed 's/linux-//')
        echo ""
        echo "=== $arch_name 架构 ==="
        ls -la "$arch_dir/"
        echo "架构验证:"
        for lib in "$arch_dir"/*.so; do
            if [ -f "$lib" ]; then
                echo "  $(basename "$lib"): $(file "$lib" | cut -d: -f2-)"
            fi
        done
    fi
done

echo ""
echo "========================================="
echo "Step 4: 构建 Java 应用程序"
echo "========================================="

# 编译 Java 代码并打包
echo "Building Java application..."
mvn compile package

# 验证构建结果
if [ -f "target/java-native-demo-multiarch-1.0.0.jar" ]; then
    echo "✓ JAR file created successfully"
    ls -lh target/*.jar
    
    echo ""
    echo "验证 JAR 包中的 native libraries:"
    jar tf target/java-native-demo-multiarch-1.0.0.jar | grep "^native/" | sort
    
else
    echo "✗ JAR file creation failed"
    exit 1
fi

echo ""
echo "========================================="
echo "构建完成总结"
echo "========================================="

# 统计支持的架构
SUPPORTED_ARCHS=""
if [ -d "target/native/linux-x86_64" ]; then
    SUPPORTED_ARCHS="$SUPPORTED_ARCHS x86_64"
fi
if [ -d "target/native/linux-aarch64" ]; then
    SUPPORTED_ARCHS="$SUPPORTED_ARCHS ARM64"
fi

echo "✅ 构建成功完成！"
echo "📦 JAR 包: target/java-native-demo-multiarch-1.0.0.jar"
echo "🏗️  支持架构:$SUPPORTED_ARCHS"
echo "📁 JAR 包大小: $(du -h target/java-native-demo-multiarch-1.0.0.jar | cut -f1)"

echo ""
echo "🚀 运行方式:"
echo "  # 通用运行（自动检测架构）:"
echo "  java -jar target/java-native-demo-multiarch-1.0.0.jar"
echo ""
echo "  # 使用部署脚本:"
echo "  ./run-multiarch.sh"
echo ""
echo "  # Docker 运行:"
echo "  docker build -t java-native-demo ."
echo "  docker run --rm java-native-demo"

echo ""
echo "========================================="
