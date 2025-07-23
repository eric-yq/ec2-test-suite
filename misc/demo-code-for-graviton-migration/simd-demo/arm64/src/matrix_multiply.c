#include "../include/simd_utils.h"

// Scalar (non-SIMD) implementation of matrix multiplication
void matrix_multiply_scalar(float* A, float* B, float* C, int M, int N, int K) {
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < N; j++) {
            float sum = 0.0f;
            for (int k = 0; k < K; k++) {
                sum += A[i * K + k] * B[k * N + j];
            }
            C[i * N + j] = sum;
        }
    }
}

// NEON implementation of matrix multiplication
void matrix_multiply_neon(float* A, float* B, float* C, int M, int N, int K) {
    // Ensure N is a multiple of 4 for NEON
    int N_padded = (N + 3) & ~3;
    
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < N; j += 4) {
            float32x4_t sum = vdupq_n_f32(0.0f);
            
            for (int k = 0; k < K; k++) {
                float32x4_t a = vdupq_n_f32(A[i * K + k]);
                float32x4_t b;
                
                // Handle edge case where j+4 might exceed N
                if (j + 4 <= N) {
                    b = vld1q_f32(&B[k * N + j]);
                } else {
                    // Create a temporary array for the edge case
                    float temp[4] = {0};
                    for (int l = 0; l < N - j; l++) {
                        temp[l] = B[k * N + j + l];
                    }
                    b = vld1q_f32(temp);
                }
                
                // Multiply and accumulate: sum += a * b
                sum = vmlaq_f32(sum, a, b);
            }
            
            // Store the result
            if (j + 4 <= N) {
                vst1q_f32(&C[i * N + j], sum);
            } else {
                // Handle edge case
                float temp[4];
                vst1q_f32(temp, sum);
                for (int l = 0; l < N - j; l++) {
                    C[i * N + j + l] = temp[l];
                }
            }
        }
    }
}

// SVE implementation of matrix multiplication
void matrix_multiply_sve(float* A, float* B, float* C, int M, int N, int K) {
#if defined(__ARM_FEATURE_SVE)
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < N; j += svcntw()) {
            // Get the vector length for this CPU
            int vl = svcntw();
            
            // Create a predicate for the remaining elements
            svbool_t pred = svwhilelt_b32(j, N);
            
            // Initialize accumulator to zero
            svfloat32_t sum = svdup_f32(0.0f);
            
            for (int k = 0; k < K; k++) {
                // Broadcast A[i,k] to all elements
                svfloat32_t a = svdup_f32(A[i * K + k]);
                
                // Load B[k,j:j+vl] with predication
                svfloat32_t b = svld1_f32(pred, &B[k * N + j]);
                
                // Multiply and accumulate: sum += a * b
                sum = svmla_f32_x(pred, sum, a, b);
            }
            
            // Store the result with predication
            svst1_f32(pred, &C[i * N + j], sum);
        }
    }
#else
    // Fallback to scalar implementation if SVE is not supported
    matrix_multiply_scalar(A, B, C, M, N, K);
#endif
}

// SVE2 implementation of matrix multiplication
void matrix_multiply_sve2(float* A, float* B, float* C, int M, int N, int K) {
#if defined(__ARM_FEATURE_SVE2)
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < N; j += svcntw()) {
            // Get the vector length for this CPU
            int vl = svcntw();
            
            // Create a predicate for the remaining elements
            svbool_t pred = svwhilelt_b32(j, N);
            
            // Initialize accumulator to zero
            svfloat32_t sum = svdup_f32(0.0f);
            
            for (int k = 0; k < K; k++) {
                // Broadcast A[i,k] to all elements
                svfloat32_t a = svdup_f32(A[i * K + k]);
                
                // Load B[k,j:j+vl] with predication
                svfloat32_t b = svld1_f32(pred, &B[k * N + j]);
                
                // Multiply and accumulate: sum += a * b
                // SVE2 might have additional optimizations or instructions
                sum = svmla_f32_x(pred, sum, a, b);
            }
            
            // Store the result with predication
            svst1_f32(pred, &C[i * N + j], sum);
        }
    }
#else
    // Fallback to SVE or scalar implementation if SVE2 is not supported
    #if defined(__ARM_FEATURE_SVE)
        matrix_multiply_sve(A, B, C, M, N, K);
    #else
        matrix_multiply_scalar(A, B, C, M, N, K);
    #endif
#endif
}
