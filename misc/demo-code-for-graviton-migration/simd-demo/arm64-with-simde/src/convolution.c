#include "../include/simd_utils.h"

// Scalar (non-SIMD) implementation of convolution
void convolution_scalar(float* input, float* kernel, float* output, int input_height, int input_width, int kernel_size) {
    int output_height = input_height - kernel_size + 1;
    int output_width = input_width - kernel_size + 1;
    
    for (int oh = 0; oh < output_height; oh++) {
        for (int ow = 0; ow < output_width; ow++) {
            float sum = 0.0f;
            
            for (int kh = 0; kh < kernel_size; kh++) {
                for (int kw = 0; kw < kernel_size; kw++) {
                    int ih = oh + kh;
                    int iw = ow + kw;
                    sum += input[ih * input_width + iw] * kernel[kh * kernel_size + kw];
                }
            }
            
            output[oh * output_width + ow] = sum;
        }
    }
}

// SSE implementation of convolution
void convolution_sse(float* input, float* kernel, float* output, int input_height, int input_width, int kernel_size) {
    int output_height = input_height - kernel_size + 1;
    int output_width = input_width - kernel_size + 1;
    
    // Process 4 output elements at a time
    for (int oh = 0; oh < output_height; oh++) {
        for (int ow = 0; ow < output_width; ow += 4) {
            __m128 sum0 = _mm_setzero_ps();
            __m128 sum1 = _mm_setzero_ps();
            __m128 sum2 = _mm_setzero_ps();
            __m128 sum3 = _mm_setzero_ps();
            
            // Check if we have enough elements left
            int remaining = output_width - ow;
            if (remaining < 4) {
                // Fall back to scalar for the last few elements
                for (int i = 0; i < remaining; i++) {
                    float sum = 0.0f;
                    for (int kh = 0; kh < kernel_size; kh++) {
                        for (int kw = 0; kw < kernel_size; kw++) {
                            int ih = oh + kh;
                            int iw = ow + i + kw;
                            sum += input[ih * input_width + iw] * kernel[kh * kernel_size + kw];
                        }
                    }
                    output[oh * output_width + ow + i] = sum;
                }
                continue;
            }
            
            // Process the convolution for 4 output elements
            for (int kh = 0; kh < kernel_size; kh++) {
                for (int kw = 0; kw < kernel_size; kw++) {
                    float k = kernel[kh * kernel_size + kw];
                    __m128 kernel_val = _mm_set1_ps(k);
                    
                    int ih = oh + kh;
                    int iw0 = ow + kw;
                    int iw1 = iw0 + 1;
                    int iw2 = iw0 + 2;
                    int iw3 = iw0 + 3;
                    
                    __m128 input_vals = _mm_set_ps(
                        input[ih * input_width + iw3],
                        input[ih * input_width + iw2],
                        input[ih * input_width + iw1],
                        input[ih * input_width + iw0]
                    );
                    
                    sum0 = _mm_add_ps(sum0, _mm_mul_ps(input_vals, kernel_val));
                }
            }
            
            // Store the results
            float results[4];
            _mm_storeu_ps(results, sum0);
            
            for (int i = 0; i < 4 && ow + i < output_width; i++) {
                output[oh * output_width + ow + i] = results[i];
            }
        }
    }
}

// AVX implementation of convolution
void convolution_avx(float* input, float* kernel, float* output, int input_height, int input_width, int kernel_size) {
    int output_height = input_height - kernel_size + 1;
    int output_width = input_width - kernel_size + 1;
    
    // Process 8 output elements at a time
    for (int oh = 0; oh < output_height; oh++) {
        for (int ow = 0; ow < output_width; ow += 8) {
            __m256 sum = _mm256_setzero_ps();
            
            // Check if we have enough elements left
            int remaining = output_width - ow;
            if (remaining < 8) {
                // Fall back to scalar for the last few elements
                for (int i = 0; i < remaining; i++) {
                    float sum_scalar = 0.0f;
                    for (int kh = 0; kh < kernel_size; kh++) {
                        for (int kw = 0; kw < kernel_size; kw++) {
                            int ih = oh + kh;
                            int iw = ow + i + kw;
                            sum_scalar += input[ih * input_width + iw] * kernel[kh * kernel_size + kw];
                        }
                    }
                    output[oh * output_width + ow + i] = sum_scalar;
                }
                continue;
            }
            
            // Process the convolution for 8 output elements
            for (int kh = 0; kh < kernel_size; kh++) {
                for (int kw = 0; kw < kernel_size; kw++) {
                    float k = kernel[kh * kernel_size + kw];
                    __m256 kernel_val = _mm256_set1_ps(k);
                    
                    int ih = oh + kh;
                    int iw = ow + kw;
                    
                    // Load 8 input values
                    float input_buffer[8];
                    for (int i = 0; i < 8; i++) {
                        input_buffer[i] = input[ih * input_width + (iw + i)];
                    }
                    __m256 input_vals = _mm256_loadu_ps(input_buffer);
                    
                    // Multiply and accumulate
                    sum = _mm256_add_ps(sum, _mm256_mul_ps(input_vals, kernel_val));
                }
            }
            
            // Store the results
            float results[8];
            _mm256_storeu_ps(results, sum);
            
            for (int i = 0; i < 8; i++) {
                output[oh * output_width + ow + i] = results[i];
            }
        }
    }
}

// AVX2 implementation of convolution
void convolution_avx2(float* input, float* kernel, float* output, int input_height, int input_width, int kernel_size) {
    int output_height = input_height - kernel_size + 1;
    int output_width = input_width - kernel_size + 1;
    
    // Process 8 output elements at a time
    for (int oh = 0; oh < output_height; oh++) {
        for (int ow = 0; ow < output_width; ow += 8) {
            __m256 sum = _mm256_setzero_ps();
            
            // Check if we have enough elements left
            int remaining = output_width - ow;
            if (remaining < 8) {
                // Fall back to scalar for the last few elements
                for (int i = 0; i < remaining; i++) {
                    float sum_scalar = 0.0f;
                    for (int kh = 0; kh < kernel_size; kh++) {
                        for (int kw = 0; kw < kernel_size; kw++) {
                            int ih = oh + kh;
                            int iw = ow + i + kw;
                            sum_scalar += input[ih * input_width + iw] * kernel[kh * kernel_size + kw];
                        }
                    }
                    output[oh * output_width + ow + i] = sum_scalar;
                }
                continue;
            }
            
            // Process the convolution for 8 output elements
            for (int kh = 0; kh < kernel_size; kh++) {
                for (int kw = 0; kw < kernel_size; kw++) {
                    float k = kernel[kh * kernel_size + kw];
                    __m256 kernel_val = _mm256_set1_ps(k);
                    
                    int ih = oh + kh;
                    int iw = ow + kw;
                    
                    // Load 8 input values
                    float input_buffer[8];
                    for (int i = 0; i < 8; i++) {
                        input_buffer[i] = input[ih * input_width + (iw + i)];
                    }
                    __m256 input_vals = _mm256_loadu_ps(input_buffer);
                    
                    // Use FMA: sum = sum + (input_vals * kernel_val)
                    sum = _mm256_fmadd_ps(input_vals, kernel_val, sum);
                }
            }
            
            // Store the results
            float results[8];
            _mm256_storeu_ps(results, sum);
            
            for (int i = 0; i < 8; i++) {
                output[oh * output_width + ow + i] = results[i];
            }
        }
    }
}

// AVX-512 implementation of convolution
void convolution_avx512(float* input, float* kernel, float* output, int input_height, int input_width, int kernel_size) {
    int output_height = input_height - kernel_size + 1;
    int output_width = input_width - kernel_size + 1;
    
    // Process 16 output elements at a time
    for (int oh = 0; oh < output_height; oh++) {
        for (int ow = 0; ow < output_width; ow += 16) {
            __m512 sum = _mm512_setzero_ps();
            
            // Check if we have enough elements left
            int remaining = output_width - ow;
            if (remaining < 16) {
                // Fall back to scalar for the last few elements
                for (int i = 0; i < remaining; i++) {
                    float sum_scalar = 0.0f;
                    for (int kh = 0; kh < kernel_size; kh++) {
                        for (int kw = 0; kw < kernel_size; kw++) {
                            int ih = oh + kh;
                            int iw = ow + i + kw;
                            sum_scalar += input[ih * input_width + iw] * kernel[kh * kernel_size + kw];
                        }
                    }
                    output[oh * output_width + ow + i] = sum_scalar;
                }
                continue;
            }
            
            // Process the convolution for 16 output elements
            for (int kh = 0; kh < kernel_size; kh++) {
                for (int kw = 0; kw < kernel_size; kw++) {
                    float k = kernel[kh * kernel_size + kw];
                    __m512 kernel_val = _mm512_set1_ps(k);
                    
                    int ih = oh + kh;
                    int iw = ow + kw;
                    
                    // Load 16 input values
                    float input_buffer[16];
                    for (int i = 0; i < 16; i++) {
                        input_buffer[i] = input[ih * input_width + (iw + i)];
                    }
                    __m512 input_vals = _mm512_loadu_ps(input_buffer);
                    
                    // Use FMA: sum = sum + (input_vals * kernel_val)
                    sum = _mm512_fmadd_ps(input_vals, kernel_val, sum);
                }
            }
            
            // Store the results
            float results[16];
            _mm512_storeu_ps(results, sum);
            
            for (int i = 0; i < 16; i++) {
                output[oh * output_width + ow + i] = results[i];
            }
        }
    }
}
