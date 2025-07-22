#include "simd_demo.h"

namespace VectorMath {

void demo_vector_operations() {
    std::cout << "向量加法性能对比:" << std::endl;
    
    // 准备测试数据
    std::vector<float> a(ARRAY_SIZE), b(ARRAY_SIZE), result(ARRAY_SIZE);
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<float> dis(-100.0f, 100.0f);
    
    for (size_t i = 0; i < ARRAY_SIZE; ++i) {
        a[i] = dis(gen);
        b[i] = dis(gen);
    }
    
    // 性能测试
    auto start = std::chrono::high_resolution_clock::now();
    
    // 标量版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 1000; ++i) {
        vector_add_scalar(a.data(), b.data(), result.data(), ARRAY_SIZE);
    }
    auto end = std::chrono::high_resolution_clock::now();
    double scalar_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("标量版本", scalar_time);
    
    // SSE版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 1000; ++i) {
        vector_add_sse(a.data(), b.data(), result.data(), ARRAY_SIZE);
    }
    end = std::chrono::high_resolution_clock::now();
    double sse_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("SSE版本", sse_time, scalar_time / sse_time);
    
    // AVX版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 1000; ++i) {
        vector_add_avx(a.data(), b.data(), result.data(), ARRAY_SIZE);
    }
    end = std::chrono::high_resolution_clock::now();
    double avx_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("AVX版本", avx_time, scalar_time / avx_time);
    
    // AVX2版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 1000; ++i) {
        vector_add_avx2(a.data(), b.data(), result.data(), ARRAY_SIZE);
    }
    end = std::chrono::high_resolution_clock::now();
    double avx2_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("AVX2版本", avx2_time, scalar_time / avx2_time);
    
#ifdef AVX512_SUPPORTED
    // AVX512版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 1000; ++i) {
        vector_add_avx512(a.data(), b.data(), result.data(), ARRAY_SIZE);
    }
    end = std::chrono::high_resolution_clock::now();
    double avx512_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("AVX512版本", avx512_time, scalar_time / avx512_time);
#endif
    
    // 点积演示
    vector_dot_product_demo();
}

void vector_add_scalar(const float* a, const float* b, float* result, size_t size) {
    for (size_t i = 0; i < size; ++i) {
        result[i] = a[i] + b[i];
    }
}

void vector_add_sse(const float* a, const float* b, float* result, size_t size) {
    size_t simd_size = size - (size % 4);
    
    for (size_t i = 0; i < simd_size; i += 4) {
        __m128 va = _mm_load_ps(&a[i]);
        __m128 vb = _mm_load_ps(&b[i]);
        __m128 vr = _mm_add_ps(va, vb);
        _mm_store_ps(&result[i], vr);
    }
    
    // 处理剩余元素
    for (size_t i = simd_size; i < size; ++i) {
        result[i] = a[i] + b[i];
    }
}

void vector_add_avx(const float* a, const float* b, float* result, size_t size) {
    size_t simd_size = size - (size % 8);
    
    for (size_t i = 0; i < simd_size; i += 8) {
        __m256 va = _mm256_load_ps(&a[i]);
        __m256 vb = _mm256_load_ps(&b[i]);
        __m256 vr = _mm256_add_ps(va, vb);
        _mm256_store_ps(&result[i], vr);
    }
    
    // 处理剩余元素
    for (size_t i = simd_size; i < size; ++i) {
        result[i] = a[i] + b[i];
    }
}

void vector_add_avx2(const float* a, const float* b, float* result, size_t size) {
    size_t simd_size = size - (size % 8);
    
    for (size_t i = 0; i < simd_size; i += 8) {
        __m256 va = _mm256_loadu_ps(&a[i]);
        __m256 vb = _mm256_loadu_ps(&b[i]);
        __m256 vr = _mm256_add_ps(va, vb);
        _mm256_storeu_ps(&result[i], vr);
    }
    
    // 处理剩余元素
    for (size_t i = simd_size; i < size; ++i) {
        result[i] = a[i] + b[i];
    }
}

#ifdef AVX512_SUPPORTED
void vector_add_avx512(const float* a, const float* b, float* result, size_t size) {
    size_t simd_size = size - (size % 16);
    
    for (size_t i = 0; i < simd_size; i += 16) {
        __m512 va = _mm512_loadu_ps(&a[i]);
        __m512 vb = _mm512_loadu_ps(&b[i]);
        __m512 vr = _mm512_add_ps(va, vb);
        _mm512_storeu_ps(&result[i], vr);
    }
    
    // 处理剩余元素
    for (size_t i = simd_size; i < size; ++i) {
        result[i] = a[i] + b[i];
    }
}
#endif

void vector_dot_product_demo() {
    std::cout << "\n向量点积性能对比:" << std::endl;
    
    std::vector<float> a(ARRAY_SIZE), b(ARRAY_SIZE);
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<float> dis(-1.0f, 1.0f);
    
    for (size_t i = 0; i < ARRAY_SIZE; ++i) {
        a[i] = dis(gen);
        b[i] = dis(gen);
    }
    
    float result;
    auto start = std::chrono::high_resolution_clock::now();
    
    // 标量版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 10000; ++i) {
        result = dot_product_scalar(a.data(), b.data(), ARRAY_SIZE);
    }
    auto end = std::chrono::high_resolution_clock::now();
    double scalar_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("标量版本", scalar_time);
    std::cout << "  结果: " << result << std::endl;
    
    // SSE版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 10000; ++i) {
        result = dot_product_sse(a.data(), b.data(), ARRAY_SIZE);
    }
    end = std::chrono::high_resolution_clock::now();
    double sse_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("SSE版本", sse_time, scalar_time / sse_time);
    std::cout << "  结果: " << result << std::endl;
    
    // AVX版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 10000; ++i) {
        result = dot_product_avx(a.data(), b.data(), ARRAY_SIZE);
    }
    end = std::chrono::high_resolution_clock::now();
    double avx_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("AVX版本", avx_time, scalar_time / avx_time);
    std::cout << "  结果: " << result << std::endl;
}

float dot_product_scalar(const float* a, const float* b, size_t size) {
    float sum = 0.0f;
    for (size_t i = 0; i < size; ++i) {
        sum += a[i] * b[i];
    }
    return sum;
}

float dot_product_sse(const float* a, const float* b, size_t size) {
    __m128 sum_vec = _mm_setzero_ps();
    size_t simd_size = size - (size % 4);
    
    for (size_t i = 0; i < simd_size; i += 4) {
        __m128 va = _mm_loadu_ps(&a[i]);
        __m128 vb = _mm_loadu_ps(&b[i]);
        __m128 prod = _mm_mul_ps(va, vb);
        sum_vec = _mm_add_ps(sum_vec, prod);
    }
    
    // 水平求和
    __m128 shuf = _mm_shuffle_ps(sum_vec, sum_vec, _MM_SHUFFLE(2, 3, 0, 1));
    __m128 sums = _mm_add_ps(sum_vec, shuf);
    shuf = _mm_movehl_ps(shuf, sums);
    sums = _mm_add_ss(sums, shuf);
    float result = _mm_cvtss_f32(sums);
    
    // 处理剩余元素
    for (size_t i = simd_size; i < size; ++i) {
        result += a[i] * b[i];
    }
    
    return result;
}

float dot_product_avx(const float* a, const float* b, size_t size) {
    __m256 sum_vec = _mm256_setzero_ps();
    size_t simd_size = size - (size % 8);
    
    for (size_t i = 0; i < simd_size; i += 8) {
        __m256 va = _mm256_loadu_ps(&a[i]);
        __m256 vb = _mm256_loadu_ps(&b[i]);
        __m256 prod = _mm256_mul_ps(va, vb);
        sum_vec = _mm256_add_ps(sum_vec, prod);
    }
    
    // 水平求和
    __m128 sum_high = _mm256_extractf128_ps(sum_vec, 1);
    __m128 sum_low = _mm256_castps256_ps128(sum_vec);
    __m128 sum = _mm_add_ps(sum_low, sum_high);
    
    __m128 shuf = _mm_shuffle_ps(sum, sum, _MM_SHUFFLE(2, 3, 0, 1));
    __m128 sums = _mm_add_ps(sum, shuf);
    shuf = _mm_movehl_ps(shuf, sums);
    sums = _mm_add_ss(sums, shuf);
    float result = _mm_cvtss_f32(sums);
    
    // 处理剩余元素
    for (size_t i = simd_size; i < size; ++i) {
        result += a[i] * b[i];
    }
    
    return result;
}

} // namespace VectorMath
