#ifndef SIMD_UTILS_H
#define SIMD_UTILS_H

#include <immintrin.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

// Function declarations for matrix multiplication
void matrix_multiply_scalar(float* A, float* B, float* C, int M, int N, int K);
void matrix_multiply_sse(float* A, float* B, float* C, int M, int N, int K);
void matrix_multiply_avx(float* A, float* B, float* C, int M, int N, int K);
void matrix_multiply_avx2(float* A, float* B, float* C, int M, int N, int K);
void matrix_multiply_avx512(float* A, float* B, float* C, int M, int N, int K);

// Function declarations for convolution
void convolution_scalar(float* input, float* kernel, float* output, int input_height, int input_width, int kernel_size);
void convolution_sse(float* input, float* kernel, float* output, int input_height, int input_width, int kernel_size);
void convolution_avx(float* input, float* kernel, float* output, int input_height, int input_width, int kernel_size);
void convolution_avx2(float* input, float* kernel, float* output, int input_height, int input_width, int kernel_size);
void convolution_avx512(float* input, float* kernel, float* output, int input_height, int input_width, int kernel_size);

// Utility functions
void init_random_matrix(float* matrix, int rows, int cols);
void init_random_kernel(float* kernel, int size);
void print_matrix(float* matrix, int rows, int cols, const char* name);
void print_kernel(float* kernel, int size, const char* name);
double get_time();
int check_avx512_support();
int check_avx2_support();
int check_avx_support();
int check_sse_support();

#endif // SIMD_UTILS_H
