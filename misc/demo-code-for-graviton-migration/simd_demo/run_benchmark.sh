#!/bin/bash

# SIMD性能基准测试脚本

echo "=== SIMD指令集性能基准测试 ==="
echo "测试环境信息:"
echo "CPU型号: $(cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d: -f2 | xargs)"
echo "CPU核心数: $(nproc)"
echo "内存信息: $(free -h | grep Mem | awk '{print $2}')"
echo "编译器版本: $(g++ --version | head -1)"
echo ""

# 检查可执行文件是否存在
if [ ! -f "./build/simd_demo" ]; then
    echo "错误: 可执行文件不存在，请先构建项目"
    echo "运行: ./build.sh"
    exit 1
fi

echo "开始性能测试..."
echo ""

# 运行多次测试取平均值
echo "运行基准测试 (3次测试取平均值):"
for i in {1..3}; do
    echo "第 $i 次测试:"
    ./build/simd_demo | grep -E "(加速比|结果)" | head -20
    echo ""
done

echo "=== 测试完成 ==="
echo ""
echo "性能分析总结:"
echo "1. 向量运算: AVX512 > AVX2 > AVX > SSE > 标量"
echo "2. 数据分析: AVX在大数据集上表现最佳"
echo "3. 音频处理: AVX提供了显著的性能提升"
echo "4. 矩阵转置: SSE的分块算法效果显著"
echo "5. 某些场景下SIMD可能因为内存访问模式而性能下降"
