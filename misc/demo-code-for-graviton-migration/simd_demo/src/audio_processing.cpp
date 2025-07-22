#include "simd_demo.h"

namespace AudioProcessing {

void demo_audio_operations() {
    std::cout << "音频增益处理性能对比:" << std::endl;
    
    std::vector<float> input(AUDIO_SAMPLES);
    std::vector<float> output(AUDIO_SAMPLES);
    const float gain = 1.5f;
    
    // 生成测试音频数据
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<float> dis(-1.0f, 1.0f);
    
    for (size_t i = 0; i < AUDIO_SAMPLES; ++i) {
        input[i] = dis(gen);
    }
    
    auto start = std::chrono::high_resolution_clock::now();
    
    // 标量版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 10000; ++i) {
        apply_gain_scalar(input.data(), output.data(), gain, AUDIO_SAMPLES);
    }
    auto end = std::chrono::high_resolution_clock::now();
    double scalar_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("标量版本", scalar_time);
    
    // SSE版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 10000; ++i) {
        apply_gain_sse(input.data(), output.data(), gain, AUDIO_SAMPLES);
    }
    end = std::chrono::high_resolution_clock::now();
    double sse_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("SSE版本", sse_time, scalar_time / sse_time);
    
    // AVX版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 10000; ++i) {
        apply_gain_avx(input.data(), output.data(), gain, AUDIO_SAMPLES);
    }
    end = std::chrono::high_resolution_clock::now();
    double avx_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("AVX版本", avx_time, scalar_time / avx_time);
    
    // 音频混合演示
    audio_mixing_demo();
}

void apply_gain_scalar(const float* input, float* output, float gain, size_t samples) {
    for (size_t i = 0; i < samples; ++i) {
        output[i] = input[i] * gain;
        
        // 限幅处理
        if (output[i] > 1.0f) output[i] = 1.0f;
        else if (output[i] < -1.0f) output[i] = -1.0f;
    }
}

void apply_gain_sse(const float* input, float* output, float gain, size_t samples) {
    const __m128 gain_vec = _mm_set1_ps(gain);
    const __m128 max_val = _mm_set1_ps(1.0f);
    const __m128 min_val = _mm_set1_ps(-1.0f);
    
    size_t simd_samples = samples - (samples % 4);
    
    for (size_t i = 0; i < simd_samples; i += 4) {
        __m128 input_vec = _mm_loadu_ps(&input[i]);
        __m128 result = _mm_mul_ps(input_vec, gain_vec);
        
        // 限幅处理
        result = _mm_min_ps(result, max_val);
        result = _mm_max_ps(result, min_val);
        
        _mm_storeu_ps(&output[i], result);
    }
    
    // 处理剩余样本
    for (size_t i = simd_samples; i < samples; ++i) {
        output[i] = input[i] * gain;
        if (output[i] > 1.0f) output[i] = 1.0f;
        else if (output[i] < -1.0f) output[i] = -1.0f;
    }
}

void apply_gain_avx(const float* input, float* output, float gain, size_t samples) {
    const __m256 gain_vec = _mm256_set1_ps(gain);
    const __m256 max_val = _mm256_set1_ps(1.0f);
    const __m256 min_val = _mm256_set1_ps(-1.0f);
    
    size_t simd_samples = samples - (samples % 8);
    
    for (size_t i = 0; i < simd_samples; i += 8) {
        __m256 input_vec = _mm256_loadu_ps(&input[i]);
        __m256 result = _mm256_mul_ps(input_vec, gain_vec);
        
        // 限幅处理
        result = _mm256_min_ps(result, max_val);
        result = _mm256_max_ps(result, min_val);
        
        _mm256_storeu_ps(&output[i], result);
    }
    
    // 处理剩余样本
    for (size_t i = simd_samples; i < samples; ++i) {
        output[i] = input[i] * gain;
        if (output[i] > 1.0f) output[i] = 1.0f;
        else if (output[i] < -1.0f) output[i] = -1.0f;
    }
}

void audio_mixing_demo() {
    std::cout << "\n音频混合性能对比:" << std::endl;
    
    std::vector<float> input1(AUDIO_SAMPLES);
    std::vector<float> input2(AUDIO_SAMPLES);
    std::vector<float> output(AUDIO_SAMPLES);
    
    // 生成测试音频数据
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<float> dis(-0.5f, 0.5f);
    
    for (size_t i = 0; i < AUDIO_SAMPLES; ++i) {
        input1[i] = dis(gen);
        input2[i] = dis(gen);
    }
    
    auto start = std::chrono::high_resolution_clock::now();
    
    // 标量版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 10000; ++i) {
        mix_audio_scalar(input1.data(), input2.data(), output.data(), AUDIO_SAMPLES);
    }
    auto end = std::chrono::high_resolution_clock::now();
    double scalar_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("标量版本", scalar_time);
    
    // AVX版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 10000; ++i) {
        mix_audio_avx(input1.data(), input2.data(), output.data(), AUDIO_SAMPLES);
    }
    end = std::chrono::high_resolution_clock::now();
    double avx_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("AVX版本", avx_time, scalar_time / avx_time);
}

void mix_audio_scalar(const float* input1, const float* input2, float* output, size_t samples) {
    for (size_t i = 0; i < samples; ++i) {
        // 简单的音频混合：平均值
        output[i] = (input1[i] + input2[i]) * 0.5f;
        
        // 限幅处理
        if (output[i] > 1.0f) output[i] = 1.0f;
        else if (output[i] < -1.0f) output[i] = -1.0f;
    }
}

void mix_audio_avx(const float* input1, const float* input2, float* output, size_t samples) {
    const __m256 mix_factor = _mm256_set1_ps(0.5f);
    const __m256 max_val = _mm256_set1_ps(1.0f);
    const __m256 min_val = _mm256_set1_ps(-1.0f);
    
    size_t simd_samples = samples - (samples % 8);
    
    for (size_t i = 0; i < simd_samples; i += 8) {
        __m256 input1_vec = _mm256_loadu_ps(&input1[i]);
        __m256 input2_vec = _mm256_loadu_ps(&input2[i]);
        
        // 混合音频
        __m256 mixed = _mm256_add_ps(input1_vec, input2_vec);
        __m256 result = _mm256_mul_ps(mixed, mix_factor);
        
        // 限幅处理
        result = _mm256_min_ps(result, max_val);
        result = _mm256_max_ps(result, min_val);
        
        _mm256_storeu_ps(&output[i], result);
    }
    
    // 处理剩余样本
    for (size_t i = simd_samples; i < samples; ++i) {
        output[i] = (input1[i] + input2[i]) * 0.5f;
        if (output[i] > 1.0f) output[i] = 1.0f;
        else if (output[i] < -1.0f) output[i] = -1.0f;
    }
}

} // namespace AudioProcessing
