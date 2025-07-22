#!/bin/bash

# SIMD性能可视化脚本

echo "🚀 SIMD指令集性能可视化报告"
echo "=================================="
echo ""

# 运行程序并提取关键性能数据
echo "📊 正在收集性能数据..."
RESULT=$(./build/simd_demo 2>/dev/null)

echo ""
echo "🏆 TOP 性能提升场景"
echo "===================="

# 提取加速比数据并排序
echo "$RESULT" | grep "加速比" | grep -v "0\." | sort -k4 -nr | head -10 | while read line; do
    # 提取加速比数值
    speedup=$(echo "$line" | grep -o '[0-9]\+\.[0-9]\+x' | head -1)
    scenario=$(echo "$line" | awk '{print $1}')
    
    # 创建简单的条形图
    value=$(echo "$speedup" | sed 's/x//')
    bars=$(printf "%.0f" "$value")
    bar_display=""
    for ((i=1; i<=bars && i<=20; i++)); do
        bar_display+="█"
    done
    
    printf "%-15s %6s %s\n" "$scenario" "$speedup" "$bar_display"
done

echo ""
echo "📈 各场景性能总览"
echo "=================="

echo ""
echo "🔢 向量数学运算:"
echo "$RESULT" | grep -A 10 "向量加法性能对比" | grep "版本:" | while read line; do
    version=$(echo "$line" | awk '{print $1}')
    speedup=$(echo "$line" | grep -o '[0-9]\+\.[0-9]\+x' || echo "1.00x")
    printf "  %-12s %s\n" "$version" "$speedup"
done

echo ""
echo "🖼️  图像处理:"
echo "$RESULT" | grep -A 5 "RGB转灰度图性能对比" | grep "版本:" | while read line; do
    version=$(echo "$line" | awk '{print $1}')
    speedup=$(echo "$line" | grep -o '[0-9]\+\.[0-9]\+x' || echo "1.00x")
    printf "  %-12s %s\n" "$version" "$speedup"
done

echo ""
echo "🔢 矩阵运算:"
echo "$RESULT" | grep -A 8 "矩阵乘法性能对比" | grep "版本:" | while read line; do
    version=$(echo "$line" | awk '{print $1}')
    speedup=$(echo "$line" | grep -o '[0-9]\+\.[0-9]\+x' || echo "1.00x")
    printf "  %-12s %s\n" "$version" "$speedup"
done

echo ""
echo "🎵 音频处理:"
echo "$RESULT" | grep -A 5 "音频增益处理性能对比" | grep "版本:" | while read line; do
    version=$(echo "$line" | awk '{print $1}')
    speedup=$(echo "$line" | grep -o '[0-9]\+\.[0-9]\+x' || echo "1.00x")
    printf "  %-12s %s\n" "$version" "$speedup"
done

echo ""
echo "📊 数据分析:"
echo "$RESULT" | grep -A 8 "数据均值计算性能对比" | grep "版本:" | while read line; do
    version=$(echo "$line" | awk '{print $1}')
    speedup=$(echo "$line" | grep -o '[0-9]\+\.[0-9]\+x' || echo "1.00x")
    printf "  %-12s %s\n" "$version" "$speedup"
done

echo ""
echo "💡 性能分析总结"
echo "================"
echo "🟢 优秀表现 (>5x):  数据分析、向量运算"
echo "🟡 良好表现 (2-5x): 音频处理、矩阵转置"  
echo "🔴 需要优化 (<2x):  图像处理、矩阵乘法"
echo ""
echo "🎯 推荐使用场景:"
echo "  • AVX:    数据分析、统计计算"
echo "  • SSE:    矩阵转置、基础向量运算"
echo "  • AVX512: 大规模向量运算"
echo ""
echo "⚠️  注意事项:"
echo "  • 确保数据内存对齐"
echo "  • 选择合适的算法实现"
echo "  • 考虑缓存友好的数据访问模式"
