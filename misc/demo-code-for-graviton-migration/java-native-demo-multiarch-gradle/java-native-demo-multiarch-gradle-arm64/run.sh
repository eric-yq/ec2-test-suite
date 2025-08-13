#!/bin/bash

# Java Native Demo Run Script (Multi-architecture support)

set -e

echo "=== Java Native Demo Run Script ==="
echo "Architecture: $(uname -m)"

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

# 检查 JAR 文件是否存在
JAR_FILE="build/libs/java-native-demo-multiarch-gradle-arm64-1.0.0-all.jar"

if [ ! -f "$JAR_FILE" ]; then
    echo "JAR file not found: $JAR_FILE"
    echo "Please run ./build.sh or ./build-fast.sh first to build the application"
    exit 1
fi

# 创建日志目录
mkdir -p logs

echo "Starting Java Native Demo Application..."
echo "JAR file: $JAR_FILE"
echo "Java version: $(java -version 2>&1 | head -n 1)"
echo "Logs will be written to: logs/native-demo.log"
echo "This JAR supports both x86_64 and ARM64 architectures"
echo ""

# 运行应用
java -Xmx512m -Xms256m -XX:+UseG1GC \
     -Djava.library.path=src/main/resources/native \
     -jar "$JAR_FILE" "$@"
