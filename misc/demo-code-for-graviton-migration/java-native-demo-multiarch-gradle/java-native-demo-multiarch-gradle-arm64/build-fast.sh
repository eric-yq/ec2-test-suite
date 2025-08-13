#!/bin/bash

# Fast Build Script - 增量构建，避免重复编译

set -e

echo "=== Fast Multi-Architecture Build ==="
echo "Current Architecture: $(uname -m)"

# 检测架构并设置 Java 环境
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
        ;;
    aarch64)
        export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-arm64
        ;;
    *)
        echo "ERROR: Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

export PATH=$JAVA_HOME/bin:$PATH

# 检查是否需要完全清理
if [ "$1" = "--clean" ]; then
    echo "Performing clean build..."
    ./gradlew clean build fatJar -x test --no-daemon
else
    echo "Performing incremental build..."
    # 增量构建，只编译变化的部分
    ./gradlew build fatJar -x test --no-daemon
fi

echo ""
echo "=== Fast build completed ==="
echo "Generated JAR: build/libs/java-native-demo-multiarch-gradle-arm64-1.0.0-all.jar"
echo ""
echo "To run: java -jar build/libs/java-native-demo-multiarch-gradle-arm64-1.0.0-all.jar"
