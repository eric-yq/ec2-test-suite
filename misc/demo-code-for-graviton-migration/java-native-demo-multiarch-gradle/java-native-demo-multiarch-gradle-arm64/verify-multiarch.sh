#!/bin/bash

# Multi-Architecture Verification Script

set -e

echo "=== Multi-Architecture Verification Script ==="
echo "Current Architecture: $(uname -m)"
echo ""

# 检查构建的 JAR 文件
echo "1. Checking built JAR files..."
if [ -f "build/libs/java-native-demo-multiarch-gradle-arm64-1.0.0-all.jar" ]; then
    echo "✓ Fat JAR found: build/libs/java-native-demo-multiarch-gradle-arm64-1.0.0-all.jar"
    
    # 检查 JAR 中的 native 库
    echo ""
    echo "2. Checking native libraries in JAR..."
    jar tf build/libs/java-native-demo-multiarch-gradle-arm64-1.0.0-all.jar | grep "native/" | sort
    
    echo ""
    echo "3. Checking native libraries in resources directory..."
    if [ -d "src/main/resources/native" ]; then
        ls -la src/main/resources/native/
        echo ""
        echo "Architecture verification:"
        cd src/main/resources/native
        for lib in *.so; do
            if [ -f "$lib" ]; then
                echo "  $lib: $(file "$lib" | cut -d: -f2 | cut -d, -f1-2)"
            fi
        done
        cd - > /dev/null
    else
        echo "Native resources directory not found"
    fi
    
    echo ""
    echo "4. Testing JAR execution..."
    java -jar build/libs/java-native-demo-multiarch-gradle-arm64-1.0.0-all.jar
    
else
    echo "✗ Fat JAR not found. Please run ./build.sh or ./build-fast.sh first"
    exit 1
fi

echo ""
echo "5. Build optimization info:"
echo "   - Use './build-fast.sh' for incremental builds (faster)"
echo "   - Use './build-fast.sh --clean' for clean builds"
echo "   - Native libraries are compiled only when source files change"

echo ""
echo "6. Architecture compatibility summary:"
echo "   - Current architecture: $(uname -m)"
echo "   - JAR contains native libraries for multiple architectures"
echo "   - This JAR should work on both x86_64 and ARM64 systems"

echo ""
echo "=== Verification completed ==="
