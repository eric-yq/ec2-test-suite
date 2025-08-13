#!/bin/bash

# Java Native Demo Run Script (x86_64 only)

set -e

echo "=== Java Native Demo Run Script ==="
echo "Architecture: $(uname -m)"

# 设置 Java 环境
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

# 检查架构
if [ "$(uname -m)" != "x86_64" ]; then
    echo "ERROR: This application only supports x86_64 architecture"
    echo "Current architecture: $(uname -m)"
    exit 1
fi

# 检查 JAR 文件是否存在
JAR_FILE="build/libs/java-native-demo-multiarch-gradle-x86-1.0.0-all.jar"

if [ ! -f "$JAR_FILE" ]; then
    echo "JAR file not found: $JAR_FILE"
    echo "Please run ./build.sh first to build the application"
    exit 1
fi

# 创建日志目录
mkdir -p logs

echo "Starting Java Native Demo Application..."
echo "JAR file: $JAR_FILE"
echo "Java version: $(java -version 2>&1 | head -n 1)"
echo "Logs will be written to: logs/native-demo.log"
echo ""

# 运行应用
java -Xmx512m -Xms256m -XX:+UseG1GC \
     -Djava.library.path=src/main/resources/native \
     -jar "$JAR_FILE" "$@"
