#!/bin/bash

# Java Native Demo Build Script (Multi-architecture support)

set -e

echo "=== Java Native Demo Multi-Architecture Build Script ==="
echo "Current Architecture: $(uname -m)"

# 检测架构并设置 Java 环境
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
        echo "Detected x86_64 architecture"
        ;;
    aarch64)
        export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-arm64
        echo "Detected ARM64 architecture"
        ;;
    *)
        echo "ERROR: Unsupported architecture: $ARCH"
        echo "Supported architectures: x86_64, aarch64"
        exit 1
        ;;
esac

export PATH=$JAVA_HOME/bin:$PATH

# 检查必要工具
echo "Checking build tools..."
command -v gcc >/dev/null 2>&1 || { echo "ERROR: gcc is required but not installed"; exit 1; }
command -v g++ >/dev/null 2>&1 || { echo "ERROR: g++ is required but not installed"; exit 1; }
command -v make >/dev/null 2>&1 || { echo "ERROR: make is required but not installed"; exit 1; }

echo "Build tools check passed"
echo "Using Java: $(java -version 2>&1 | head -n 1)"

# 检查交叉编译工具
echo "Checking cross compilation tools..."
cd native
make check-cross
cd ..

# 询问是否安装交叉编译工具
if [ "$1" != "--skip-cross-check" ]; then
    echo ""
    echo "Do you want to install missing cross compilation tools? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "Installing cross compilation tools..."
        cd native
        make install-cross-tools
        cd ..
    fi
fi

# 创建 native resources 目录
mkdir -p src/main/resources/native

# 构建 Java 应用（Gradle 会自动处理 native 库编译和复制）
echo "Building Java application with native libraries..."
echo "Note: Native libraries will be compiled automatically by Gradle"
./gradlew clean build fatJar -x test --no-daemon

echo "=== Build completed successfully ==="
echo "Generated files:"
echo "  - JAR: build/libs/java-native-demo-multiarch-gradle-arm64-1.0.0.jar"
echo "  - Fat JAR: build/libs/java-native-demo-multiarch-gradle-arm64-1.0.0-all.jar"

echo ""
echo "Native libraries included:"
ls -la src/main/resources/native/ 2>/dev/null || echo "Native libraries are embedded in JAR"

echo ""
echo "This JAR can run on both x86_64 and ARM64 architectures!"
echo ""
echo "To run the application:"
echo "  java -jar build/libs/java-native-demo-multiarch-gradle-arm64-1.0.0-all.jar"
echo "  or"
echo "  ./run.sh"
