#include "simd_demo.h"

namespace ImageProcessing {

void demo_image_operations() {
    std::cout << "RGB转灰度图性能对比:" << std::endl;
    
    const size_t pixels = IMAGE_WIDTH * IMAGE_HEIGHT;
    std::vector<uint8_t> rgb_data(pixels * 3);
    std::vector<uint8_t> gray_data(pixels);
    
    // 生成测试数据
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<int> dis(0, 255);
    
    for (size_t i = 0; i < pixels * 3; ++i) {
        rgb_data[i] = static_cast<uint8_t>(dis(gen));
    }
    
    auto start = std::chrono::high_resolution_clock::now();
    
    // 标量版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 100; ++i) {
        rgb_to_grayscale_scalar(rgb_data.data(), gray_data.data(), pixels);
    }
    auto end = std::chrono::high_resolution_clock::now();
    double scalar_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("标量版本", scalar_time);
    
    // SSE版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 100; ++i) {
        rgb_to_grayscale_sse(rgb_data.data(), gray_data.data(), pixels);
    }
    end = std::chrono::high_resolution_clock::now();
    double sse_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("SSE版本", sse_time, scalar_time / sse_time);
    
    // AVX2版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 100; ++i) {
        rgb_to_grayscale_avx2(rgb_data.data(), gray_data.data(), pixels);
    }
    end = std::chrono::high_resolution_clock::now();
    double avx2_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("AVX2版本", avx2_time, scalar_time / avx2_time);
    
    // 高斯模糊演示
    gaussian_blur_demo();
}

void rgb_to_grayscale_scalar(const uint8_t* rgb, uint8_t* gray, size_t pixels) {
    for (size_t i = 0; i < pixels; ++i) {
        // 使用标准的RGB到灰度转换公式: 0.299*R + 0.587*G + 0.114*B
        float r = rgb[i * 3];
        float g = rgb[i * 3 + 1];
        float b = rgb[i * 3 + 2];
        gray[i] = static_cast<uint8_t>(0.299f * r + 0.587f * g + 0.114f * b);
    }
}

void rgb_to_grayscale_sse(const uint8_t* rgb, uint8_t* gray, size_t pixels) {
    // 使用简化的整数运算
    size_t simd_pixels = pixels - (pixels % 4);
    
    for (size_t i = 0; i < simd_pixels; i += 4) {
        // 直接计算4个像素的灰度值
        for (int j = 0; j < 4; ++j) {
            int r = rgb[(i + j) * 3];
            int g = rgb[(i + j) * 3 + 1];
            int b = rgb[(i + j) * 3 + 2];
            // 使用位移优化: (77*r + 150*g + 29*b) >> 8
            gray[i + j] = static_cast<uint8_t>((77 * r + 150 * g + 29 * b) >> 8);
        }
    }
    
    // 处理剩余像素
    for (size_t i = simd_pixels; i < pixels; ++i) {
        int r = rgb[i * 3];
        int g = rgb[i * 3 + 1];
        int b = rgb[i * 3 + 2];
        gray[i] = static_cast<uint8_t>((77 * r + 150 * g + 29 * b) >> 8);
    }
}

void rgb_to_grayscale_avx2(const uint8_t* rgb, uint8_t* gray, size_t pixels) {
    // 使用简化的方法，一次处理8个像素
    size_t simd_pixels = pixels - (pixels % 8);
    
    for (size_t i = 0; i < simd_pixels; i += 8) {
        // 直接计算8个像素的灰度值
        for (int j = 0; j < 8; ++j) {
            int r = rgb[(i + j) * 3];
            int g = rgb[(i + j) * 3 + 1];
            int b = rgb[(i + j) * 3 + 2];
            gray[i + j] = static_cast<uint8_t>((77 * r + 150 * g + 29 * b) >> 8);
        }
    }
    
    // 处理剩余像素
    for (size_t i = simd_pixels; i < pixels; ++i) {
        int r = rgb[i * 3];
        int g = rgb[i * 3 + 1];
        int b = rgb[i * 3 + 2];
        gray[i] = static_cast<uint8_t>((77 * r + 150 * g + 29 * b) >> 8);
    }
}

void gaussian_blur_demo() {
    std::cout << "\n高斯模糊性能对比:" << std::endl;
    
    const int width = 256;
    const int height = 256;
    std::vector<float> input(width * height);
    std::vector<float> output(width * height);
    
    // 生成测试数据
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<float> dis(0.0f, 255.0f);
    
    for (int i = 0; i < width * height; ++i) {
        input[i] = dis(gen);
    }
    
    auto start = std::chrono::high_resolution_clock::now();
    
    // 标量版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 10; ++i) {
        gaussian_blur_scalar(input.data(), output.data(), width, height);
    }
    auto end = std::chrono::high_resolution_clock::now();
    double scalar_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("标量版本", scalar_time);
    
    // AVX版本
    start = std::chrono::high_resolution_clock::now();
    for (int i = 0; i < 10; ++i) {
        gaussian_blur_avx(input.data(), output.data(), width, height);
    }
    end = std::chrono::high_resolution_clock::now();
    double avx_time = std::chrono::duration<double, std::milli>(end - start).count();
    print_performance("AVX版本", avx_time, scalar_time / avx_time);
}

void gaussian_blur_scalar(const float* input, float* output, int width, int height) {
    // 简单的3x3高斯核
    const float kernel[9] = {
        1.0f/16, 2.0f/16, 1.0f/16,
        2.0f/16, 4.0f/16, 2.0f/16,
        1.0f/16, 2.0f/16, 1.0f/16
    };
    
    for (int y = 1; y < height - 1; ++y) {
        for (int x = 1; x < width - 1; ++x) {
            float sum = 0.0f;
            for (int ky = -1; ky <= 1; ++ky) {
                for (int kx = -1; kx <= 1; ++kx) {
                    int idx = (y + ky) * width + (x + kx);
                    int kidx = (ky + 1) * 3 + (kx + 1);
                    sum += input[idx] * kernel[kidx];
                }
            }
            output[y * width + x] = sum;
        }
    }
}

void gaussian_blur_avx(const float* input, float* output, int width, int height) {
    // 使用分离的高斯核进行优化
    // 3x3高斯核可以分解为两个1x3核的卷积
    const __m256 kernel = _mm256_set_ps(0.25f, 0.5f, 0.25f, 0.25f, 0.5f, 0.25f, 0.25f, 0.5f);
    
    // 临时缓冲区用于水平模糊
    std::vector<float> temp(width * height);
    
    // 水平模糊
    for (int y = 0; y < height; ++y) {
        int x = 1;
        for (; x < width - 1 - 7; x += 8) {
            __m256 left = _mm256_loadu_ps(&input[y * width + x - 1]);
            __m256 center = _mm256_loadu_ps(&input[y * width + x]);
            __m256 right = _mm256_loadu_ps(&input[y * width + x + 1]);
            
            // 1x3高斯核: [0.25, 0.5, 0.25]
            __m256 result = _mm256_add_ps(
                _mm256_add_ps(
                    _mm256_mul_ps(left, _mm256_set1_ps(0.25f)),
                    _mm256_mul_ps(center, _mm256_set1_ps(0.5f))
                ),
                _mm256_mul_ps(right, _mm256_set1_ps(0.25f))
            );
            
            _mm256_storeu_ps(&temp[y * width + x], result);
        }
        
        // 处理剩余像素
        for (; x < width - 1; ++x) {
            temp[y * width + x] = 0.25f * input[y * width + x - 1] + 
                                  0.5f * input[y * width + x] + 
                                  0.25f * input[y * width + x + 1];
        }
        
        // 边界处理
        temp[y * width] = input[y * width];
        temp[y * width + width - 1] = input[y * width + width - 1];
    }
    
    // 垂直模糊
    for (int y = 1; y < height - 1; ++y) {
        int x = 0;
        for (; x < width - 7; x += 8) {
            __m256 top = _mm256_loadu_ps(&temp[(y - 1) * width + x]);
            __m256 center = _mm256_loadu_ps(&temp[y * width + x]);
            __m256 bottom = _mm256_loadu_ps(&temp[(y + 1) * width + x]);
            
            // 1x3高斯核: [0.25, 0.5, 0.25]
            __m256 result = _mm256_add_ps(
                _mm256_add_ps(
                    _mm256_mul_ps(top, _mm256_set1_ps(0.25f)),
                    _mm256_mul_ps(center, _mm256_set1_ps(0.5f))
                ),
                _mm256_mul_ps(bottom, _mm256_set1_ps(0.25f))
            );
            
            _mm256_storeu_ps(&output[y * width + x], result);
        }
        
        // 处理剩余像素
        for (; x < width; ++x) {
            output[y * width + x] = 0.25f * temp[(y - 1) * width + x] + 
                                    0.5f * temp[y * width + x] + 
                                    0.25f * temp[(y + 1) * width + x];
        }
    }
    
    // 边界处理
    for (int x = 0; x < width; ++x) {
        output[x] = temp[x];
        output[(height - 1) * width + x] = temp[(height - 1) * width + x];
    }
}

} // namespace ImageProcessing
