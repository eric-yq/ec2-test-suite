#!/bin/bash

# Java Native Demo 构建脚本
set -e

echo "Java Native Library Demo - Build Script"
echo "======================================="

# 检查Java环境
if ! command -v java &> /dev/null; then
    echo "Error: Java is not installed or not in PATH"
    exit 1
fi

if ! command -v mvn &> /dev/null; then
    echo "Error: Maven is not installed or not in PATH"
    exit 1
fi

# 检查编译工具
if ! command -v g++ &> /dev/null; then
    echo "Error: g++ is not installed"
    exit 1
fi

echo "Building native library..."
cd native
make clean
make
make install
cd ..

echo "Building Java application..."
mvn clean package

echo "Build completed successfully!"
echo "JAR file location: target/java-native-demo-1.0.0.jar"

echo ""
echo "To run the application:"
echo "  java -jar target/java-native-demo-1.0.0.jar"
echo ""
echo "To build Docker image:"
echo "  docker build -t java-native-demo ."
echo ""
echo "To run Docker container:"
echo "  docker run --rm java-native-demo"
