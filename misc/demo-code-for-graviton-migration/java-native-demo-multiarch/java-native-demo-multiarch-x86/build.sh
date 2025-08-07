#!/bin/bash

# Complete Build Script

set -e

echo "========================================="
echo "Java Native Demo Multi-Architecture Build"
echo "========================================="

# 检查 Java 环境
if [ -z "$JAVA_HOME" ]; then
    echo "JAVA_HOME is not set. Trying to detect..."
    if [ -d "/usr/lib/jvm/java-11-openjdk-amd64" ]; then
        export JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
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
        exit 1
    else
        echo "✓ $tool found"
    fi
done

# 清理之前的构建
echo "Cleaning previous build..."
mvn clean

# 构建 native libraries
echo "Building native libraries..."
./build-native.sh

# 编译 Java 代码并打包
echo "Building Java application..."
mvn compile package

# 验证构建结果
if [ -f "target/java-native-demo-multiarch-1.0.0.jar" ]; then
    echo "✓ JAR file created successfully"
    ls -la target/*.jar
else
    echo "✗ JAR file creation failed"
    exit 1
fi

echo "========================================="
echo "Build completed successfully!"
echo "========================================="
echo ""
echo "To run the application:"
echo "  java -Djava.library.path=target/native/linux-x86_64 -jar target/java-native-demo-multiarch-1.0.0.jar"
echo ""
echo "Or use Docker:"
echo "  docker build -t java-native-demo ."
echo "  docker run --rm java-native-demo"
