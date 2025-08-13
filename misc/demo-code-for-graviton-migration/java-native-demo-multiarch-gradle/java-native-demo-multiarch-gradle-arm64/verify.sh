#!/bin/bash

# Verification Script for Java Native Demo

set -e

echo "=== Java Native Demo Verification ==="
echo "Architecture: $(uname -m)"
echo ""

# 设置 Java 环境
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

# 1. 检查架构
echo "1. Checking architecture..."
if [ "$(uname -m)" != "x86_64" ]; then
    echo "❌ ERROR: Only x86_64 architecture is supported"
    exit 1
else
    echo "✅ Architecture check passed: x86_64"
fi

# 2. 检查必要工具
echo ""
echo "2. Checking required tools..."
TOOLS=("gcc" "g++" "make" "java" "javac")
for tool in "${TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "✅ $tool: $(which $tool)"
    else
        echo "❌ $tool: not found"
        exit 1
    fi
done

# 3. 检查 Java 版本
echo ""
echo "3. Checking Java version..."
JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2)
echo "✅ Java version: $JAVA_VERSION"

# 4. 验证项目结构
echo ""
echo "4. Verifying project structure..."
REQUIRED_FILES=(
    "build.gradle"
    "src/main/java/com/example/demo/NativeDemoApplication.java"
    "native/Makefile"
    "native/src/math_ops.c"
    "native/src/string_ops.c"
    "native/src/system_ops.cpp"
    "Dockerfile"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file: missing"
        exit 1
    fi
done

# 5. 编译 native libraries
echo ""
echo "5. Compiling native libraries..."
cd native
make clean >/dev/null 2>&1
if make all >/dev/null 2>&1; then
    echo "✅ Native libraries compiled successfully"
    ls -la build/*.so | while read line; do
        echo "   $line"
    done
else
    echo "❌ Native library compilation failed"
    exit 1
fi
cd ..

# 6. 复制 native libraries
echo ""
echo "6. Copying native libraries to resources..."
cp native/build/*.so src/main/resources/native/
echo "✅ Native libraries copied to resources"

# 7. 检查 Gradle 构建
echo ""
echo "7. Testing Gradle build..."
if ./gradlew clean compileJava --no-daemon >/dev/null 2>&1; then
    echo "✅ Gradle build test passed"
else
    echo "❌ Gradle build test failed"
    exit 1
fi

# 8. 构建完整项目
echo ""
echo "8. Building complete project..."
if ./gradlew clean build fatJar -x test --no-daemon >/dev/null 2>&1; then
    echo "✅ Complete project build passed"
    echo "   Generated JAR files:"
    ls -la build/libs/*.jar | while read line; do
        echo "   $line"
    done
else
    echo "❌ Complete project build failed"
    exit 1
fi

echo ""
echo "=== All verifications passed! ==="
echo ""
echo "Next steps:"
echo "1. Run the application: ./run.sh"
echo "2. Build Docker image: ./docker-build.sh"
echo "3. Run tests: ./gradlew test"
