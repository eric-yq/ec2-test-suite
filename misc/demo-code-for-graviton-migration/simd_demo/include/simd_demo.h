#ifndef SIMD_DEMO_H
#define SIMD_DEMO_H

#include <immintrin.h>
#include <xmmintrin.h>
#include <emmintrin.h>
#include <pmmintrin.h>
#include <tmmintrin.h>
#include <smmintrin.h>
#include <nmmintrin.h>
#include <wmmintrin.h>
#include <avxintrin.h>
#include <avx2intrin.h>

#ifdef AVX512_SUPPORTED
#include <avx512fintrin.h>
#include <avx512dqintrin.h>
#include <avx512bwintrin.h>
#include <avx512vlintrin.h>
#endif

#include <iostream>
#include <vector>
#include <chrono>
#include <random>
#include <cstring>
#include <cmath>
#include <iomanip>
#include <algorithm>
#include <initializer_list>

// 常量定义
#define ARRAY_SIZE 1024
#define IMAGE_WIDTH 512
#define IMAGE_HEIGHT 512
#define MATRIX_SIZE 256
#define AUDIO_SAMPLES 2048

// 工具函数
void print_performance(const char* name, double time_ms, double speedup = 0.0);
bool check_cpu_support();
void print_cpu_features();

// 场景1: 向量数学运算
namespace VectorMath {
    void demo_vector_operations();
    void vector_add_scalar(const float* a, const float* b, float* result, size_t size);
    void vector_add_sse(const float* a, const float* b, float* result, size_t size);
    void vector_add_avx(const float* a, const float* b, float* result, size_t size);
    void vector_add_avx2(const float* a, const float* b, float* result, size_t size);
    #ifdef AVX512_SUPPORTED
    void vector_add_avx512(const float* a, const float* b, float* result, size_t size);
    #endif
    
    void vector_dot_product_demo();
    float dot_product_scalar(const float* a, const float* b, size_t size);
    float dot_product_sse(const float* a, const float* b, size_t size);
    float dot_product_avx(const float* a, const float* b, size_t size);
}

// 场景2: 图像处理
namespace ImageProcessing {
    void demo_image_operations();
    void rgb_to_grayscale_scalar(const uint8_t* rgb, uint8_t* gray, size_t pixels);
    void rgb_to_grayscale_sse(const uint8_t* rgb, uint8_t* gray, size_t pixels);
    void rgb_to_grayscale_avx2(const uint8_t* rgb, uint8_t* gray, size_t pixels);
    
    void gaussian_blur_demo();
    void gaussian_blur_scalar(const float* input, float* output, int width, int height);
    void gaussian_blur_avx(const float* input, float* output, int width, int height);
}

// 场景3: 矩阵运算
namespace MatrixOperations {
    void demo_matrix_operations();
    void matrix_multiply_scalar(const float* a, const float* b, float* c, size_t n);
    void matrix_multiply_sse(const float* a, const float* b, float* c, size_t n);
    void matrix_multiply_avx(const float* a, const float* b, float* c, size_t n);
    void matrix_multiply_avx2(const float* a, const float* b, float* c, size_t n);
    
    void matrix_transpose_demo();
    void matrix_transpose_scalar(const float* input, float* output, size_t rows, size_t cols);
    void matrix_transpose_sse(const float* input, float* output, size_t rows, size_t cols);
}

// 场景4: 音频处理
namespace AudioProcessing {
    void demo_audio_operations();
    void apply_gain_scalar(const float* input, float* output, float gain, size_t samples);
    void apply_gain_sse(const float* input, float* output, float gain, size_t samples);
    void apply_gain_avx(const float* input, float* output, float gain, size_t samples);
    
    void audio_mixing_demo();
    void mix_audio_scalar(const float* input1, const float* input2, float* output, size_t samples);
    void mix_audio_avx(const float* input1, const float* input2, float* output, size_t samples);
}

// 场景5: 数据分析
namespace DataAnalytics {
    void demo_data_operations();
    float calculate_mean_scalar(const float* data, size_t size);
    float calculate_mean_sse(const float* data, size_t size);
    float calculate_mean_avx(const float* data, size_t size);
    
    void find_min_max_demo();
    void find_min_max_scalar(const float* data, size_t size, float* min_val, float* max_val);
    void find_min_max_sse(const float* data, size_t size, float* min_val, float* max_val);
    void find_min_max_avx(const float* data, size_t size, float* min_val, float* max_val);
}

#endif // SIMD_DEMO_H
