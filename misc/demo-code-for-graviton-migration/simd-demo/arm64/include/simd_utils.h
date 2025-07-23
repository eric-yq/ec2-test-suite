#ifndef SIMD_UTILS_H
#define SIMD_UTILS_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

// ARM NEON headers
#include <arm_neon.h>

// ARM SVE headers (if available)
#if defined(__ARM_FEATURE_SVE)
#include <arm_sve.h>
#endif

// Function declarations for matrix multiplication
void matrix_multiply_scalar(float* A, float* B, float* C, int M, int N, int K);
void matrix_multiply_neon(float* A, float* B, float* C, int M, int N, int K);
void matrix_multiply_sve(float* A, float* B, float* C, int M, int N, int K);
void matrix_multiply_sve2(float* A, float* B, float* C, int M, int N, int K);

// Function declarations for convolution
void convolution_scalar(float* input, float* kernel, float* output, int input_height, int input_width, int kernel_size);
void convolution_neon(float* input, float* kernel, float* output, int input_height, int input_width, int kernel_size);
void convolution_sve(float* input, float* kernel, float* output, int input_height, int input_width, int kernel_size);
void convolution_sve2(float* input, float* kernel, float* output, int input_height, int input_width, int kernel_size);

// Utility functions
void init_random_matrix(float* matrix, int rows, int cols);
void init_random_kernel(float* kernel, int size);
void print_matrix(float* matrix, int rows, int cols, const char* name);
void print_kernel(float* kernel, int size, const char* name);
double get_time();
int check_neon_support();
int check_sve_support();
int check_sve2_support();

#endif // SIMD_UTILS_H
