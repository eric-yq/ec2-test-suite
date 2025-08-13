#!/bin/bash

# Java Native Demo Build Script (x86_64 only)

set -e

echo "=== Java Native Demo Build Script ==="
echo "Architecture: $(uname -m)"

# 设置 Java 环境
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

# 检查架构
if [ "$(uname -m)" != "x86_64" ]; then
    echo "ERROR: This project only supports x86_64 architecture"
    echo "Current architecture: $(uname -m)"
    exit 1
fi

# 检查必要工具
echo "Checking build tools..."
command -v gcc >/dev/null 2>&1 || { echo "ERROR: gcc is required but not installed"; exit 1; }
command -v g++ >/dev/null 2>&1 || { echo "ERROR: g++ is required but not installed"; exit 1; }
command -v make >/dev/null 2>&1 || { echo "ERROR: make is required but not installed"; exit 1; }

echo "Build tools check passed"
echo "Using Java: $(java -version 2>&1 | head -n 1)"

# 构建 native libraries
echo "Building native libraries..."
cd native
make clean
make all
cd ..

# 复制 native libraries
echo "Copying native libraries to resources..."
cp native/build/*.so src/main/resources/native/

# 构建 Java 应用
echo "Building Java application..."
./gradlew clean build fatJar -x test --no-daemon

echo "=== Build completed successfully ==="
echo "Generated files:"
echo "  - JAR: build/libs/java-native-demo-multiarch-gradle-x86-1.0.0.jar"
echo "  - Fat JAR: build/libs/java-native-demo-multiarch-gradle-x86-1.0.0-all.jar"
echo "  - Native libraries: src/main/resources/native/*.so"

echo ""
echo "To run the application:"
echo "  java -jar build/libs/java-native-demo-multiarch-gradle-x86-1.0.0-all.jar"
echo "  or"
echo "  ./run.sh"
