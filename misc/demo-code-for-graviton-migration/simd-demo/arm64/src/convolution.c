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

// NEON implementation of convolution
void convolution_neon(float* input, float* kernel, float* output, int input_height, int input_width, int kernel_size) {
    int output_height = input_height - kernel_size + 1;
    int output_width = input_width - kernel_size + 1;
    
    // Process 4 output elements at a time
    for (int oh = 0; oh < output_height; oh++) {
        for (int ow = 0; ow < output_width; ow += 4) {
            float32x4_t sum = vdupq_n_f32(0.0f);
            
            // Check if we have enough elements left
            int remaining = output_width - ow;
            if (remaining < 4) {
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
            
            // Process the convolution for 4 output elements
            for (int kh = 0; kh < kernel_size; kh++) {
                for (int kw = 0; kw < kernel_size; kw++) {
                    float k = kernel[kh * kernel_size + kw];
                    float32x4_t kernel_val = vdupq_n_f32(k);
                    
                    int ih = oh + kh;
                    int iw = ow + kw;
                    
                    // Load 4 input values
                    float input_buffer[4];
                    for (int i = 0; i < 4; i++) {
                        input_buffer[i] = input[ih * input_width + (iw + i)];
                    }
                    float32x4_t input_vals = vld1q_f32(input_buffer);
                    
                    // Multiply and accumulate
                    sum = vmlaq_f32(sum, input_vals, kernel_val);
                }
            }
            
            // Store the results
            vst1q_f32(&output[oh * output_width + ow], sum);
        }
    }
}

// SVE implementation of convolution
void convolution_sve(float* input, float* kernel, float* output, int input_height, int input_width, int kernel_size) {
#if defined(__ARM_FEATURE_SVE)
    int output_height = input_height - kernel_size + 1;
    int output_width = input_width - kernel_size + 1;
    
    // Process output elements in chunks of vector length
    for (int oh = 0; oh < output_height; oh++) {
        for (int ow = 0; ow < output_width; ow += svcntw()) {
            // Get the vector length for this CPU
            int vl = svcntw();
            
            // Create a predicate for the remaining elements
            svbool_t pred = svwhilelt_b32(ow, output_width);
            
            // Initialize accumulator to zero
            svfloat32_t sum = svdup_f32(0.0f);
            
            // Process the convolution
            for (int kh = 0; kh < kernel_size; kh++) {
                for (int kw = 0; kw < kernel_size; kw++) {
                    float k = kernel[kh * kernel_size + kw];
                    svfloat32_t kernel_val = svdup_f32(k);
                    
                    int ih = oh + kh;
                    int iw = ow + kw;
                    
                    // Load input values with predication
                    svfloat32_t input_vals;
                    
                    // We need to handle the case where input values are not contiguous
                    // Create a temporary buffer for loading
                    float input_buffer[256]; // Assuming max vector length is 256
                    for (int i = 0; i < vl && (ow + i) < output_width; i++) {
                        input_buffer[i] = input[ih * input_width + (iw + i)];
                    }
                    
                    input_vals = svld1_f32(pred, input_buffer);
                    
                    // Multiply and accumulate
                    sum = svmla_f32_x(pred, sum, kernel_val, input_vals);
                }
            }
            
            // Store the results with predication
            svst1_f32(pred, &output[oh * output_width + ow], sum);
        }
    }
#else
    // Fallback to scalar implementation if SVE is not supported
    convolution_scalar(input, kernel, output, input_height, input_width, kernel_size);
#endif
}

// SVE2 implementation of convolution
void convolution_sve2(float* input, float* kernel, float* output, int input_height, int input_width, int kernel_size) {
#if defined(__ARM_FEATURE_SVE2)
    int output_height = input_height - kernel_size + 1;
    int output_width = input_width - kernel_size + 1;
    
    // Process output elements in chunks of vector length
    for (int oh = 0; oh < output_height; oh++) {
        for (int ow = 0; ow < output_width; ow += svcntw()) {
            // Get the vector length for this CPU
            int vl = svcntw();
            
            // Create a predicate for the remaining elements
            svbool_t pred = svwhilelt_b32(ow, output_width);
            
            // Initialize accumulator to zero
            svfloat32_t sum = svdup_f32(0.0f);
            
            // Process the convolution
            for (int kh = 0; kh < kernel_size; kh++) {
                for (int kw = 0; kw < kernel_size; kw++) {
                    float k = kernel[kh * kernel_size + kw];
                    svfloat32_t kernel_val = svdup_f32(k);
                    
                    int ih = oh + kh;
                    int iw = ow + kw;
                    
                    // Load input values with predication
                    svfloat32_t input_vals;
                    
                    // We need to handle the case where input values are not contiguous
                    // Create a temporary buffer for loading
                    float input_buffer[256]; // Assuming max vector length is 256
                    for (int i = 0; i < vl && (ow + i) < output_width; i++) {
                        input_buffer[i] = input[ih * input_width + (iw + i)];
                    }
                    
                    input_vals = svld1_f32(pred, input_buffer);
                    
                    // Multiply and accumulate (SVE2 might have additional optimizations)
                    sum = svmla_f32_x(pred, sum, kernel_val, input_vals);
                }
            }
            
            // Store the results with predication
            svst1_f32(pred, &output[oh * output_width + ow], sum);
        }
    }
#else
    // Fallback to SVE or scalar implementation if SVE2 is not supported
    #if defined(__ARM_FEATURE_SVE)
        convolution_sve(input, kernel, output, input_height, input_width, kernel_size);
    #else
        convolution_scalar(input, kernel, output, input_height, input_width, kernel_size);
    #endif
#endif
}
