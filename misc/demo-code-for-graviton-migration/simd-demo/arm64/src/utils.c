#include "../include/simd_utils.h"
#include <sys/time.h>

// Initialize a matrix with random values
void init_random_matrix(float* matrix, int rows, int cols) {
    for (int i = 0; i < rows * cols; i++) {
        matrix[i] = (float)rand() / RAND_MAX;
    }
}

// Initialize a convolution kernel with random values
void init_random_kernel(float* kernel, int size) {
    for (int i = 0; i < size * size; i++) {
        kernel[i] = (float)rand() / RAND_MAX;
    }
}

// Print a matrix
void print_matrix(float* matrix, int rows, int cols, const char* name) {
    printf("%s (%dx%d):\n", name, rows, cols);
    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            printf("%.4f ", matrix[i * cols + j]);
        }
        printf("\n");
    }
    printf("\n");
}

// Print a convolution kernel
void print_kernel(float* kernel, int size, const char* name) {
    printf("%s (%dx%d):\n", name, size, size);
    for (int i = 0; i < size; i++) {
        for (int j = 0; j < size; j++) {
            printf("%.4f ", kernel[i * size + j]);
        }
        printf("\n");
    }
    printf("\n");
}

// Get current time in seconds
double get_time() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec + tv.tv_usec * 1e-6;
}

// Check if NEON is supported
int check_neon_support() {
    // NEON is mandatory in ARMv8 (AArch64), so always return 1
    return 1;
}

// Check if SVE is supported
int check_sve_support() {
    #if defined(__ARM_FEATURE_SVE)
    // Runtime detection would be better, but this is a simple compile-time check
    return 1;
    #else
    return 0;
    #endif
}

// Check if SVE2 is supported
int check_sve2_support() {
    #if defined(__ARM_FEATURE_SVE2)
    // Runtime detection would be better, but this is a simple compile-time check
    return 1;
    #else
    return 0;
    #endif
}
