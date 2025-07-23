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

// SSE implementation of matrix multiplication
void matrix_multiply_sse(float* A, float* B, float* C, int M, int N, int K) {
    // Ensure N is a multiple of 4 for SSE
    int N_padded = (N + 3) & ~3;
    
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < N; j += 4) {
            __m128 sum = _mm_setzero_ps();
            
            for (int k = 0; k < K; k++) {
                __m128 a = _mm_set1_ps(A[i * K + k]);
                __m128 b;
                
                // Handle edge case where j+4 might exceed N
                if (j + 4 <= N) {
                    b = _mm_loadu_ps(&B[k * N + j]);
                } else {
                    // Create a temporary array for the edge case
                    float temp[4] = {0};
                    for (int l = 0; l < N - j; l++) {
                        temp[l] = B[k * N + j + l];
                    }
                    b = _mm_loadu_ps(temp);
                }
                
                sum = _mm_add_ps(sum, _mm_mul_ps(a, b));
            }
            
            // Store the result
            if (j + 4 <= N) {
                _mm_storeu_ps(&C[i * N + j], sum);
            } else {
                // Handle edge case
                float temp[4];
                _mm_storeu_ps(temp, sum);
                for (int l = 0; l < N - j; l++) {
                    C[i * N + j + l] = temp[l];
                }
            }
        }
    }
}

// AVX implementation of matrix multiplication
void matrix_multiply_avx(float* A, float* B, float* C, int M, int N, int K) {
    // Ensure N is a multiple of 8 for AVX
    int N_padded = (N + 7) & ~7;
    
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < N; j += 8) {
            __m256 sum = _mm256_setzero_ps();
            
            for (int k = 0; k < K; k++) {
                __m256 a = _mm256_set1_ps(A[i * K + k]);
                __m256 b;
                
                // Handle edge case where j+8 might exceed N
                if (j + 8 <= N) {
                    b = _mm256_loadu_ps(&B[k * N + j]);
                } else {
                    // Create a temporary array for the edge case
                    float temp[8] = {0};
                    for (int l = 0; l < N - j; l++) {
                        temp[l] = B[k * N + j + l];
                    }
                    b = _mm256_loadu_ps(temp);
                }
                
                sum = _mm256_add_ps(sum, _mm256_mul_ps(a, b));
            }
            
            // Store the result
            if (j + 8 <= N) {
                _mm256_storeu_ps(&C[i * N + j], sum);
            } else {
                // Handle edge case
                float temp[8];
                _mm256_storeu_ps(temp, sum);
                for (int l = 0; l < N - j; l++) {
                    C[i * N + j + l] = temp[l];
                }
            }
        }
    }
}

// AVX2 implementation of matrix multiplication
void matrix_multiply_avx2(float* A, float* B, float* C, int M, int N, int K) {
    // AVX2 adds FMA (Fused Multiply-Add) operations which can improve matrix multiplication
    // Ensure N is a multiple of 8 for AVX2
    int N_padded = (N + 7) & ~7;
    
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < N; j += 8) {
            __m256 sum = _mm256_setzero_ps();
            
            for (int k = 0; k < K; k++) {
                __m256 a = _mm256_set1_ps(A[i * K + k]);
                __m256 b;
                
                // Handle edge case where j+8 might exceed N
                if (j + 8 <= N) {
                    b = _mm256_loadu_ps(&B[k * N + j]);
                } else {
                    // Create a temporary array for the edge case
                    float temp[8] = {0};
                    for (int l = 0; l < N - j; l++) {
                        temp[l] = B[k * N + j + l];
                    }
                    b = _mm256_loadu_ps(temp);
                }
                
                // Use FMA: sum = sum + (a * b)
                sum = _mm256_fmadd_ps(a, b, sum);
            }
            
            // Store the result
            if (j + 8 <= N) {
                _mm256_storeu_ps(&C[i * N + j], sum);
            } else {
                // Handle edge case
                float temp[8];
                _mm256_storeu_ps(temp, sum);
                for (int l = 0; l < N - j; l++) {
                    C[i * N + j + l] = temp[l];
                }
            }
        }
    }
}

// AVX-512 implementation of matrix multiplication
void matrix_multiply_avx512(float* A, float* B, float* C, int M, int N, int K) {
    // Ensure N is a multiple of 16 for AVX-512
    int N_padded = (N + 15) & ~15;
    
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < N; j += 16) {
            __m512 sum = _mm512_setzero_ps();
            
            for (int k = 0; k < K; k++) {
                __m512 a = _mm512_set1_ps(A[i * K + k]);
                __m512 b;
                
                // Handle edge case where j+16 might exceed N
                if (j + 16 <= N) {
                    b = _mm512_loadu_ps(&B[k * N + j]);
                } else {
                    // Create a temporary array for the edge case
                    float temp[16] = {0};
                    for (int l = 0; l < N - j; l++) {
                        temp[l] = B[k * N + j + l];
                    }
                    b = _mm512_loadu_ps(temp);
                }
                
                // Use FMA: sum = sum + (a * b)
                sum = _mm512_fmadd_ps(a, b, sum);
            }
            
            // Store the result
            if (j + 16 <= N) {
                _mm512_storeu_ps(&C[i * N + j], sum);
            } else {
                // Handle edge case
                float temp[16];
                _mm512_storeu_ps(temp, sum);
                for (int l = 0; l < N - j; l++) {
                    C[i * N + j + l] = temp[l];
                }
            }
        }
    }
}
