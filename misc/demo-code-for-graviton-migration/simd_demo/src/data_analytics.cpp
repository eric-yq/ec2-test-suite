#include "simd_demo.h"

namespace DataAnalytics {

void demo_data_operations() {
    std::cout << "数据均值计算性能对比:" << std::endl;
    
    std::vector<float> data(ARRAY_SIZE);
    
    // 生成测试数据
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<float> dis(0.0f, 100.0f);
    
    for (size_t i = 0; i < ARRAY_SIZE; ++i) {
        data[i] = dis(gen);
    }
    
    float result;
    auto start = std::chrono::high_resolution_clock::now();
    
    // 标量版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 10000; ++i) {
        result = calculate_mean_scalar(data.data(), ARRAY_SIZE);
    }
    auto end = std::chrono::high_resolution_clock::now();
    double scalar_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("标量版本", scalar_time);
    std::cout << "  结果: " << std::fixed << std::setprecision(3) << result << std::endl;
    
    // SSE版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 10000; ++i) {
        result = calculate_mean_sse(data.data(), ARRAY_SIZE);
    }
    end = std::chrono::high_resolution_clock::now();
    double sse_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("SSE版本", sse_time, scalar_time / sse_time);
    std::cout << "  结果: " << std::fixed << std::setprecision(3) << result << std::endl;
    
    // AVX版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 10000; ++i) {
        result = calculate_mean_avx(data.data(), ARRAY_SIZE);
    }
    end = std::chrono::high_resolution_clock::now();
    double avx_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("AVX版本", avx_time, scalar_time / avx_time);
    std::cout << "  结果: " << std::fixed << std::setprecision(3) << result << std::endl;
    
    // 最值查找演示
    find_min_max_demo();
}

float calculate_mean_scalar(const float* data, size_t size) {
    float sum = 0.0f;
    for (size_t i = 0; i < size; ++i) {
        sum += data[i];
    }
    return sum / static_cast<float>(size);
}

float calculate_mean_sse(const float* data, size_t size) {
    __m128 sum_vec = _mm_setzero_ps();
    size_t simd_size = size - (size % 4);
    
    for (size_t i = 0; i < simd_size; i += 4) {
        __m128 data_vec = _mm_loadu_ps(&data[i]);
        sum_vec = _mm_add_ps(sum_vec, data_vec);
    }
    
    // 水平求和
    __m128 shuf = _mm_shuffle_ps(sum_vec, sum_vec, _MM_SHUFFLE(2, 3, 0, 1));
    __m128 sums = _mm_add_ps(sum_vec, shuf);
    shuf = _mm_movehl_ps(shuf, sums);
    sums = _mm_add_ss(sums, shuf);
    float sum = _mm_cvtss_f32(sums);
    
    // 处理剩余元素
    for (size_t i = simd_size; i < size; ++i) {
        sum += data[i];
    }
    
    return sum / static_cast<float>(size);
}

float calculate_mean_avx(const float* data, size_t size) {
    __m256 sum_vec = _mm256_setzero_ps();
    size_t simd_size = size - (size % 8);
    
    for (size_t i = 0; i < simd_size; i += 8) {
        __m256 data_vec = _mm256_loadu_ps(&data[i]);
        sum_vec = _mm256_add_ps(sum_vec, data_vec);
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
        result += data[i];
    }
    
    return result / static_cast<float>(size);
}

void find_min_max_demo() {
    std::cout << "\n最值查找性能对比:" << std::endl;
    
    std::vector<float> data(ARRAY_SIZE);
    
    // 生成测试数据
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<float> dis(-1000.0f, 1000.0f);
    
    for (size_t i = 0; i < ARRAY_SIZE; ++i) {
        data[i] = dis(gen);
    }
    
    float min_val, max_val;
    auto start = std::chrono::high_resolution_clock::now();
    
    // 标量版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 10000; ++i) {
        find_min_max_scalar(data.data(), ARRAY_SIZE, &min_val, &max_val);
    }
    auto end = std::chrono::high_resolution_clock::now();
    double scalar_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("标量版本", scalar_time);
    std::cout << "  最小值: " << std::fixed << std::setprecision(3) << min_val 
              << ", 最大值: " << max_val << std::endl;
    
    // SSE版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 10000; ++i) {
        find_min_max_sse(data.data(), ARRAY_SIZE, &min_val, &max_val);
    }
    end = std::chrono::high_resolution_clock::now();
    double sse_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("SSE版本", sse_time, scalar_time / sse_time);
    std::cout << "  最小值: " << std::fixed << std::setprecision(3) << min_val 
              << ", 最大值: " << max_val << std::endl;
    
    // AVX版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 10000; ++i) {
        find_min_max_avx(data.data(), ARRAY_SIZE, &min_val, &max_val);
    }
    end = std::chrono::high_resolution_clock::now();
    double avx_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("AVX版本", avx_time, scalar_time / avx_time);
    std::cout << "  最小值: " << std::fixed << std::setprecision(3) << min_val 
              << ", 最大值: " << max_val << std::endl;
}

void find_min_max_scalar(const float* data, size_t size, float* min_val, float* max_val) {
    if (size == 0) return;
    
    *min_val = data[0];
    *max_val = data[0];
    
    for (size_t i = 1; i < size; ++i) {
        if (data[i] < *min_val) *min_val = data[i];
        if (data[i] > *max_val) *max_val = data[i];
    }
}

void find_min_max_sse(const float* data, size_t size, float* min_val, float* max_val) {
    if (size == 0) return;
    
    __m128 min_vec = _mm_set1_ps(data[0]);
    __m128 max_vec = _mm_set1_ps(data[0]);
    
    size_t simd_size = size - (size % 4);
    
    for (size_t i = 0; i < simd_size; i += 4) {
        __m128 data_vec = _mm_loadu_ps(&data[i]);
        min_vec = _mm_min_ps(min_vec, data_vec);
        max_vec = _mm_max_ps(max_vec, data_vec);
    }
    
    // 水平最值计算
    alignas(16) float min_vals[4], max_vals[4];
    _mm_store_ps(min_vals, min_vec);
    _mm_store_ps(max_vals, max_vec);
    
    *min_val = std::min(std::min(min_vals[0], min_vals[1]), std::min(min_vals[2], min_vals[3]));
    *max_val = std::max(std::max(max_vals[0], max_vals[1]), std::max(max_vals[2], max_vals[3]));
    
    // 处理剩余元素
    for (size_t i = simd_size; i < size; ++i) {
        if (data[i] < *min_val) *min_val = data[i];
        if (data[i] > *max_val) *max_val = data[i];
    }
}

void find_min_max_avx(const float* data, size_t size, float* min_val, float* max_val) {
    if (size == 0) return;
    
    __m256 min_vec = _mm256_set1_ps(data[0]);
    __m256 max_vec = _mm256_set1_ps(data[0]);
    
    size_t simd_size = size - (size % 8);
    
    for (size_t i = 0; i < simd_size; i += 8) {
        __m256 data_vec = _mm256_loadu_ps(&data[i]);
        min_vec = _mm256_min_ps(min_vec, data_vec);
        max_vec = _mm256_max_ps(max_vec, data_vec);
    }
    
    // 水平最值计算
    alignas(32) float min_vals[8], max_vals[8];
    _mm256_store_ps(min_vals, min_vec);
    _mm256_store_ps(max_vals, max_vec);
    
    *min_val = min_vals[0];
    *max_val = max_vals[0];
    for (int i = 1; i < 8; ++i) {
        if (min_vals[i] < *min_val) *min_val = min_vals[i];
        if (max_vals[i] > *max_val) *max_val = max_vals[i];
    }
    
    // 处理剩余元素
    for (size_t i = simd_size; i < size; ++i) {
        if (data[i] < *min_val) *min_val = data[i];
        if (data[i] > *max_val) *max_val = data[i];
    }
}

} // namespace DataAnalytics
