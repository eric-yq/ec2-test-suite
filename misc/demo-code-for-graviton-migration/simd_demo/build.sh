#!/bin/bash

# SIMD演示程序构建脚本

echo "=== SIMD演示程序构建脚本 ==="

# 检查编译器
if ! command -v g++ &> /dev/null; then
    echo "错误: 未找到g++编译器"
    exit 1
fi

if ! command -v cmake &> /dev/null; then
    echo "错误: 未找到cmake"
    exit 1
fi

# 创建构建目录
mkdir -p build
cd build

# 配置项目
echo "配置项目..."
cmake .. -DCMAKE_BUILD_TYPE=Release

if [ $? -ne 0 ]; then
    echo "错误: CMake配置失败"
    exit 1
fi

# 编译项目
echo "编译项目..."
make -j$(nproc)

if [ $? -ne 0 ]; then
    echo "错误: 编译失败"
    exit 1
fi

echo "构建成功！"
echo "可执行文件位置: build/simd_demo"
echo ""
echo "运行程序:"
echo "  cd build && ./simd_demo"
echo ""
echo "或者直接运行:"
echo "  ./build/simd_demo"
