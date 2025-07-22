# SIMD指令集演示程序

这是一个完整的C/C++工程，演示了SSE/AVX/AVX2/AVX512等SIMD指令在5个主要使用场景中的应用和性能对比。

## 项目结构

```
simd_demo/
├── CMakeLists.txt          # CMake构建配置
├── build.sh               # 构建脚本
├── README.md              # 项目说明
├── include/
│   └── simd_demo.h        # 主头文件
└── src/
    ├── main.cpp           # 主程序
    ├── simd_utils.cpp     # 工具函数
    ├── vector_math.cpp    # 向量数学运算
    ├── image_processing.cpp # 图像处理
    ├── matrix_operations.cpp # 矩阵运算
    ├── audio_processing.cpp # 音频处理
    └── data_analytics.cpp # 数据分析
```

## 演示场景

### 1. 向量数学运算 (vector_math.cpp)
- **向量加法**: 标量 vs SSE vs AVX vs AVX2 vs AVX512
- **点积计算**: 标量 vs SSE vs AVX
- 展示了基础的向量运算优化

### 2. 图像处理 (image_processing.cpp)
- **RGB转灰度**: 标量 vs SSE vs AVX2
- **高斯模糊**: 标量 vs AVX
- 演示了像素级并行处理

### 3. 矩阵运算 (matrix_operations.cpp)
- **矩阵乘法**: 标量 vs SSE vs AVX vs AVX2(分块优化)
- **矩阵转置**: 标量 vs SSE(4x4分块)
- 展示了线性代数运算加速

### 4. 音频处理 (audio_processing.cpp)
- **音频增益**: 标量 vs SSE vs AVX
- **音频混合**: 标量 vs AVX
- 演示了实时音频处理优化

### 5. 数据分析 (data_analytics.cpp)
- **均值计算**: 标量 vs SSE vs AVX
- **最值查找**: 标量 vs SSE vs AVX
- 展示了统计计算加速

## 支持的指令集

- **SSE/SSE2/SSE3/SSE4.1/SSE4.2**: 128位向量运算
- **AVX**: 256位向量运算
- **AVX2**: 增强的256位整数运算
- **AVX512**: 512位向量运算 (如果CPU支持)

## 构建要求

- **编译器**: GCC 7+ 或 Clang 6+ 或 MSVC 2019+
- **CMake**: 3.10+
- **CPU**: x86/x86_64架构，支持相应SIMD指令集
- **操作系统**: Linux/Windows/macOS

## 构建方法

### 方法1: 使用构建脚本 (推荐)
```bash
./build.sh
```

### 方法2: 手动构建
```bash
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

### 方法3: Windows (Visual Studio)
```cmd
mkdir build
cd build
cmake .. -G "Visual Studio 16 2019"
cmake --build . --config Release
```

## 运行程序

```bash
cd build
./simd_demo
```

## 输出示例

程序会输出每个场景下不同SIMD指令版本的性能对比：

```
=== SIMD指令集演示程序 ===
演示SSE/AVX/AVX2/AVX512指令在不同场景中的应用

CPU特性检测:
  SSE:     支持
  SSE2:    支持
  AVX:     支持
  AVX2:    支持
  AVX512F: 支持

=== 场景1: 向量数学运算 ===
向量加法性能对比:
          标量版本:   45.234 ms
           SSE版本:   12.456 ms (加速比: 3.63x)
           AVX版本:    6.789 ms (加速比: 6.66x)
          AVX2版本:    6.234 ms (加速比: 7.26x)
        AVX512版本:    3.123 ms (加速比: 14.49x)
...
```

## 性能优化技术

1. **向量化**: 使用SIMD指令并行处理多个数据
2. **内存对齐**: 使用对齐的内存访问提高性能
3. **循环展开**: 减少循环开销
4. **分块算法**: 优化缓存局部性
5. **水平运算**: 向量内元素的归约操作

## 编译选项说明

- `-msse`, `-msse2`, `-msse3`, `-msse4.1`, `-msse4.2`: 启用SSE指令集
- `-mavx`, `-mavx2`: 启用AVX指令集
- `-mavx512f`, `-mavx512dq`, `-mavx512bw`, `-mavx512vl`: 启用AVX512指令集
- `-O3`: 最高级别优化
- `-ffast-math`: 快速数学运算 (可选)

## 注意事项

1. **CPU兼容性**: 程序会自动检测CPU支持的指令集
2. **内存对齐**: 某些操作需要内存对齐以获得最佳性能
3. **编译器优化**: 使用Release模式编译以获得最佳性能
4. **数值精度**: SIMD运算可能存在轻微的数值差异

## 扩展建议

1. 添加更多SIMD指令集支持 (如ARM NEON)
2. 实现更复杂的算法 (如FFT、卷积神经网络)
3. 添加多线程支持
4. 集成性能分析工具
5. 添加单元测试

## 参考资料

- [Intel Intrinsics Guide](https://software.intel.com/sites/landingpage/IntrinsicsGuide/)
- [AMD64 Architecture Programmer's Manual](https://www.amd.com/system/files/TechDocs/24593.pdf)
- [Agner Fog's Optimization Manuals](https://www.agner.org/optimize/)
