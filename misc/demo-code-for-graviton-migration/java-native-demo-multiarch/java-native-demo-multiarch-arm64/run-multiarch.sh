#!/bin/bash

# Multi-Architecture Deployment and Run Script
# 通用多架构部署和运行脚本

set -e

echo "========================================="
echo "Java Native Demo - Multi-Architecture Runner"
echo "Java Native Demo - 多架构通用运行器"
echo "========================================="

# 检查当前架构
ARCH=$(uname -m)
echo "当前系统架构: $ARCH"

case $ARCH in
    aarch64|arm64)
        echo "✓ 检测到 ARM64 架构"
        TARGET_ARCH="aarch64"
        NATIVE_PATH="target/native/linux-aarch64"
        ARCH_DISPLAY="ARM64 (AArch64)"
        ;;
    x86_64)
        echo "✓ 检测到 x86_64 架构"
        TARGET_ARCH="x86_64"
        NATIVE_PATH="target/native/linux-x86_64"
        ARCH_DISPLAY="x86_64 (AMD64)"
        ;;
    *)
        echo "❌ 不支持的架构: $ARCH"
        echo "支持的架构: x86_64, aarch64/arm64"
        exit 1
        ;;
esac

echo "目标架构: $ARCH_DISPLAY"

# 检查 JAR 文件是否存在
JAR_FILE="target/java-native-demo-multiarch-1.0.0.jar"
if [ ! -f "$JAR_FILE" ]; then
    echo "❌ JAR 文件不存在: $JAR_FILE"
    echo "请先运行构建脚本: ./build.sh"
    exit 1
fi

echo "✓ JAR 文件存在: $JAR_FILE"
echo "  文件大小: $(du -h "$JAR_FILE" | cut -f1)"

# 检查 Java 环境
if ! command -v java &> /dev/null; then
    echo "❌ Java 未安装"
    echo "请安装 OpenJDK 11 或更高版本:"
    echo "  Ubuntu/Debian: sudo apt-get install openjdk-11-jre"
    echo "  Amazon Linux: sudo yum install java-11-openjdk"
    exit 1
fi

echo "✓ Java 环境检查:"
java -version 2>&1 | head -3 | sed 's/^/  /'

# 检查 JAR 包中是否包含对应架构的 native libraries
echo ""
echo "检查 JAR 包中的 native libraries:"
NATIVE_LIBS_IN_JAR=$(jar tf "$JAR_FILE" | grep "^native/linux-" | head -10)
if [ -z "$NATIVE_LIBS_IN_JAR" ]; then
    echo "❌ JAR 包中未找到 native libraries"
    exit 1
fi

echo "$NATIVE_LIBS_IN_JAR" | sed 's/^/  /'

# 检查是否包含当前架构的库
CURRENT_ARCH_LIBS=$(jar tf "$JAR_FILE" | grep "^native/linux-$TARGET_ARCH/")
if [ -z "$CURRENT_ARCH_LIBS" ]; then
    echo "⚠️  JAR 包中未找到 $ARCH_DISPLAY 架构的 native libraries"
    echo "将尝试使用应用程序的自动加载机制"
else
    echo "✓ 找到 $ARCH_DISPLAY 架构的 native libraries:"
    echo "$CURRENT_ARCH_LIBS" | sed 's/^/  /'
fi

# 如果存在外部 native libraries，显示信息
if [ -d "$NATIVE_PATH" ]; then
    echo ""
    echo "外部 native libraries 信息 ($NATIVE_PATH):"
    for lib in "$NATIVE_PATH"/*.so; do
        if [ -f "$lib" ]; then
            echo "  $(basename "$lib"): $(file "$lib" | cut -d: -f2-)"
        fi
    done
fi

echo ""
echo "========================================="
echo "启动应用程序..."
echo "========================================="

# 设置 JVM 参数
JVM_OPTS="-Xmx512m -Xms256m"

# 注意：不需要设置 -Djava.library.path，因为应用程序会自动从 JAR 包中加载 native libraries
echo "使用 JAR 包内嵌的 native libraries（自动加载）"

# 如果存在外部 native libraries 目录，显示信息但不强制使用
if [ -d "$NATIVE_PATH" ]; then
    echo "检测到外部 native libraries: $NATIVE_PATH"
    echo "应用程序会优先使用 JAR 包内嵌的版本"
fi

# 运行应用程序
echo "执行命令: java $JVM_OPTS -jar $JAR_FILE"
echo ""

java $JVM_OPTS -jar "$JAR_FILE"

EXIT_CODE=$?

echo ""
echo "========================================="
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ 应用程序运行完成 (退出码: $EXIT_CODE)"
else
    echo "❌ 应用程序运行失败 (退出码: $EXIT_CODE)"
fi
echo "========================================="

exit $EXIT_CODE
