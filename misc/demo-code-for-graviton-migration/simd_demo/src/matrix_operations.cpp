#include "simd_demo.h"

namespace MatrixOperations {

void demo_matrix_operations() {
    std::cout << "矩阵乘法性能对比 (" << MATRIX_SIZE << "x" << MATRIX_SIZE << "):" << std::endl;
    
    const size_t size = MATRIX_SIZE;
    std::vector<float> a(size * size), b(size * size), c(size * size);
    
    // 生成测试数据
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<float> dis(-1.0f, 1.0f);
    
    for (size_t i = 0; i < size * size; ++i) {
        a[i] = dis(gen);
        b[i] = dis(gen);
    }
    
    auto start = std::chrono::high_resolution_clock::now();
    
    // 标量版本
    start = std::chrono::high_resolution_clock::now();
    matrix_multiply_scalar(a.data(), b.data(), c.data(), size);
    auto end = std::chrono::high_resolution_clock::now();
    double scalar_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("标量版本", scalar_time);
    
    // SSE版本
    start = std::chrono::high_resolution_clock::now();
    matrix_multiply_sse(a.data(), b.data(), c.data(), size);
    end = std::chrono::high_resolution_clock::now();
    double sse_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("SSE版本", sse_time, scalar_time / sse_time);
    
    // AVX版本
    start = std::chrono::high_resolution_clock::now();
    matrix_multiply_avx(a.data(), b.data(), c.data(), size);
    end = std::chrono::high_resolution_clock::now();
    double avx_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("AVX版本", avx_time, scalar_time / avx_time);
    
    // AVX2版本
    start = std::chrono::high_resolution_clock::now();
    matrix_multiply_avx2(a.data(), b.data(), c.data(), size);
    end = std::chrono::high_resolution_clock::now();
    double avx2_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("AVX2版本", avx2_time, scalar_time / avx2_time);
    
    // 矩阵转置演示
    matrix_transpose_demo();
}

void matrix_multiply_scalar(const float* a, const float* b, float* c, size_t n) {
    for (size_t i = 0; i < n; ++i) {
        for (size_t j = 0; j < n; ++j) {
            float sum = 0.0f;
            for (size_t k = 0; k < n; ++k) {
                sum += a[i * n + k] * b[k * n + j];
            }
            c[i * n + j] = sum;
        }
    }
}

void matrix_multiply_sse(const float* a, const float* b, float* c, size_t n) {
    // 简化的实现，专注于基本的SIMD优化
    for (size_t i = 0; i < n; ++i) {
        for (size_t j = 0; j < n; j += 4) {
            __m128 sum = _mm_setzero_ps();
            
            for (size_t k = 0; k < n; ++k) {
                __m128 a_elem = _mm_set1_ps(a[i * n + k]);
                __m128 b_vec = _mm_loadu_ps(&b[k * n + j]);
                sum = _mm_add_ps(sum, _mm_mul_ps(a_elem, b_vec));
            }
            
            _mm_storeu_ps(&c[i * n + j], sum);
        }
    }
}

void matrix_multiply_avx(const float* a, const float* b, float* c, size_t n) {
    // 简化的AVX实现
    for (size_t i = 0; i < n; ++i) {
        for (size_t j = 0; j < n; j += 8) {
            __m256 sum = _mm256_setzero_ps();
            
            for (size_t k = 0; k < n; ++k) {
                __m256 a_elem = _mm256_set1_ps(a[i * n + k]);
                __m256 b_vec = _mm256_loadu_ps(&b[k * n + j]);
                sum = _mm256_add_ps(sum, _mm256_mul_ps(a_elem, b_vec));
            }
            
            _mm256_storeu_ps(&c[i * n + j], sum);
        }
    }
}

void matrix_multiply_avx2(const float* a, const float* b, float* c, size_t n) {
    // 使用FMA指令的AVX2实现
    for (size_t i = 0; i < n; ++i) {
        for (size_t j = 0; j < n; j += 8) {
            __m256 sum = _mm256_setzero_ps();
            
            for (size_t k = 0; k < n; ++k) {
                __m256 a_elem = _mm256_set1_ps(a[i * n + k]);
                __m256 b_vec = _mm256_loadu_ps(&b[k * n + j]);
                sum = _mm256_fmadd_ps(a_elem, b_vec, sum);
            }
            
            _mm256_storeu_ps(&c[i * n + j], sum);
        }
    }
}

void matrix_transpose_demo() {
    std::cout << "\n矩阵转置性能对比 (" << MATRIX_SIZE << "x" << MATRIX_SIZE << "):" << std::endl;
    
    const size_t rows = MATRIX_SIZE;
    const size_t cols = MATRIX_SIZE;
    std::vector<float> input(rows * cols);
    std::vector<float> output(rows * cols);
    
    // 生成测试数据
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<float> dis(-1.0f, 1.0f);
    
    for (size_t i = 0; i < rows * cols; ++i) {
        input[i] = dis(gen);
    }
    
    auto start = std::chrono::high_resolution_clock::now();
    
    // 标量版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 10; ++i) {
        matrix_transpose_scalar(input.data(), output.data(), rows, cols);
    }
    auto end = std::chrono::high_resolution_clock::now();
    double scalar_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("标量版本", scalar_time);
    
    // SSE版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 10; ++i) {
        matrix_transpose_sse(input.data(), output.data(), rows, cols);
    }
    end = std::chrono::high_resolution_clock::now();
    double sse_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("SSE版本", sse_time, scalar_time / sse_time);
}

void matrix_transpose_scalar(const float* input, float* output, size_t rows, size_t cols) {
    for (size_t i = 0; i < rows; ++i) {
        for (size_t j = 0; j < cols; ++j) {
            output[j * rows + i] = input[i * cols + j];
        }
    }
}

void matrix_transpose_sse(const float* input, float* output, size_t rows, size_t cols) {
    // 4x4分块转置
    for (size_t i = 0; i < rows; i += 4) {
        for (size_t j = 0; j < cols; j += 4) {
            // 加载4x4块
            __m128 row0 = _mm_loadu_ps(&input[(i + 0) * cols + j]);
            __m128 row1 = _mm_loadu_ps(&input[(i + 1) * cols + j]);
            __m128 row2 = _mm_loadu_ps(&input[(i + 2) * cols + j]);
            __m128 row3 = _mm_loadu_ps(&input[(i + 3) * cols + j]);
            
            // 转置4x4块
            __m128 tmp0 = _mm_unpacklo_ps(row0, row1);
            __m128 tmp1 = _mm_unpackhi_ps(row0, row1);
            __m128 tmp2 = _mm_unpacklo_ps(row2, row3);
            __m128 tmp3 = _mm_unpackhi_ps(row2, row3);
            
            __m128 col0 = _mm_movelh_ps(tmp0, tmp2);
            __m128 col1 = _mm_movehl_ps(tmp2, tmp0);
            __m128 col2 = _mm_movelh_ps(tmp1, tmp3);
            __m128 col3 = _mm_movehl_ps(tmp3, tmp1);
            
            // 存储转置后的块
            _mm_storeu_ps(&output[(j + 0) * rows + i], col0);
            _mm_storeu_ps(&output[(j + 1) * rows + i], col1);
            _mm_storeu_ps(&output[(j + 2) * rows + i], col2);
            _mm_storeu_ps(&output[(j + 3) * rows + i], col3);
        }
    }
}

} // namespace MatrixOperations
