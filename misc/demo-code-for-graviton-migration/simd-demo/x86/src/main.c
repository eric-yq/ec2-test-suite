#include "../include/simd_utils.h"

void test_matrix_multiplication(int size) {
    printf("\n===== Testing Matrix Multiplication (%dx%d) =====\n", size, size);
    
    // Allocate memory for matrices
    float* A = (float*)aligned_alloc(64, size * size * sizeof(float));
    float* B = (float*)aligned_alloc(64, size * size * sizeof(float));
    float* C_scalar = (float*)aligned_alloc(64, size * size * sizeof(float));
    float* C_sse = (float*)aligned_alloc(64, size * size * sizeof(float));
    float* C_avx = (float*)aligned_alloc(64, size * size * sizeof(float));
    float* C_avx2 = (float*)aligned_alloc(64, size * size * sizeof(float));
    float* C_avx512 = (float*)aligned_alloc(64, size * size * sizeof(float));
    
    // Initialize matrices with random values
    srand(42);  // For reproducible results
    init_random_matrix(A, size, size);
    init_random_matrix(B, size, size);
    
    // Print small matrices for verification
    if (size <= 8) {
        print_matrix(A, size, size, "Matrix A");
        print_matrix(B, size, size, "Matrix B");
    }
    
    // Test scalar implementation
    double start_time = get_time();
    matrix_multiply_scalar(A, B, C_scalar, size, size, size);
    double scalar_time = get_time() - start_time;
    printf("Scalar implementation: %.6f seconds\n", scalar_time);
    
    // Test SSE implementation if supported
    if (check_sse_support()) {
        start_time = get_time();
        matrix_multiply_sse(A, B, C_sse, size, size, size);
        double sse_time = get_time() - start_time;
        printf("SSE implementation: %.6f seconds (%.2fx speedup)\n", 
               sse_time, scalar_time / sse_time);
    } else {
        printf("SSE not supported on this CPU\n");
    }
    
    // Test AVX implementation if supported
    if (check_avx_support()) {
        start_time = get_time();
        matrix_multiply_avx(A, B, C_avx, size, size, size);
        double avx_time = get_time() - start_time;
        printf("AVX implementation: %.6f seconds (%.2fx speedup)\n", 
               avx_time, scalar_time / avx_time);
    } else {
        printf("AVX not supported on this CPU\n");
    }
    
    // Test AVX2 implementation if supported
    if (check_avx2_support()) {
        start_time = get_time();
        matrix_multiply_avx2(A, B, C_avx2, size, size, size);
        double avx2_time = get_time() - start_time;
        printf("AVX2 implementation: %.6f seconds (%.2fx speedup)\n", 
               avx2_time, scalar_time / avx2_time);
    } else {
        printf("AVX2 not supported on this CPU\n");
    }
    
    // Test AVX-512 implementation if supported
    if (check_avx512_support()) {
        start_time = get_time();
        matrix_multiply_avx512(A, B, C_avx512, size, size, size);
        double avx512_time = get_time() - start_time;
        printf("AVX-512 implementation: %.6f seconds (%.2fx speedup)\n", 
               avx512_time, scalar_time / avx512_time);
    } else {
        printf("AVX-512 not supported on this CPU\n");
    }
    
    // Print small result matrices for verification
    if (size <= 8) {
        print_matrix(C_scalar, size, size, "Result (Scalar)");
        if (check_sse_support()) print_matrix(C_sse, size, size, "Result (SSE)");
        if (check_avx_support()) print_matrix(C_avx, size, size, "Result (AVX)");
        if (check_avx2_support()) print_matrix(C_avx2, size, size, "Result (AVX2)");
        if (check_avx512_support()) print_matrix(C_avx512, size, size, "Result (AVX-512)");
    }
    
    // Free memory
    free(A);
    free(B);
    free(C_scalar);
    free(C_sse);
    free(C_avx);
    free(C_avx2);
    free(C_avx512);
}

void test_convolution(int input_size, int kernel_size) {
    printf("\n===== Testing Convolution (Input: %dx%d, Kernel: %dx%d) =====\n", 
           input_size, input_size, kernel_size, kernel_size);
    
    int output_size = input_size - kernel_size + 1;
    
    // Allocate memory
    float* input = (float*)aligned_alloc(64, input_size * input_size * sizeof(float));
    float* kernel = (float*)aligned_alloc(64, kernel_size * kernel_size * sizeof(float));
    float* output_scalar = (float*)aligned_alloc(64, output_size * output_size * sizeof(float));
    float* output_sse = (float*)aligned_alloc(64, output_size * output_size * sizeof(float));
    float* output_avx = (float*)aligned_alloc(64, output_size * output_size * sizeof(float));
    float* output_avx2 = (float*)aligned_alloc(64, output_size * output_size * sizeof(float));
    float* output_avx512 = (float*)aligned_alloc(64, output_size * output_size * sizeof(float));
    
    // Initialize with random values
    srand(42);  // For reproducible results
    init_random_matrix(input, input_size, input_size);
    init_random_kernel(kernel, kernel_size);
    
    // Print small inputs for verification
    if (input_size <= 8) {
        print_matrix(input, input_size, input_size, "Input");
        print_kernel(kernel, kernel_size, "Kernel");
    }
    
    // Test scalar implementation
    double start_time = get_time();
    convolution_scalar(input, kernel, output_scalar, input_size, input_size, kernel_size);
    double scalar_time = get_time() - start_time;
    printf("Scalar implementation: %.6f seconds\n", scalar_time);
    
    // Test SSE implementation if supported
    if (check_sse_support()) {
        start_time = get_time();
        convolution_sse(input, kernel, output_sse, input_size, input_size, kernel_size);
        double sse_time = get_time() - start_time;
        printf("SSE implementation: %.6f seconds (%.2fx speedup)\n", 
               sse_time, scalar_time / sse_time);
    } else {
        printf("SSE not supported on this CPU\n");
    }
    
    // Test AVX implementation if supported
    if (check_avx_support()) {
        start_time = get_time();
        convolution_avx(input, kernel, output_avx, input_size, input_size, kernel_size);
        double avx_time = get_time() - start_time;
        printf("AVX implementation: %.6f seconds (%.2fx speedup)\n", 
               avx_time, scalar_time / avx_time);
    } else {
        printf("AVX not supported on this CPU\n");
    }
    
    // Test AVX2 implementation if supported
    if (check_avx2_support()) {
        start_time = get_time();
        convolution_avx2(input, kernel, output_avx2, input_size, input_size, kernel_size);
        double avx2_time = get_time() - start_time;
        printf("AVX2 implementation: %.6f seconds (%.2fx speedup)\n", 
               avx2_time, scalar_time / avx2_time);
    } else {
        printf("AVX2 not supported on this CPU\n");
    }
    
    // Test AVX-512 implementation if supported
    if (check_avx512_support()) {
        start_time = get_time();
        convolution_avx512(input, kernel, output_avx512, input_size, input_size, kernel_size);
        double avx512_time = get_time() - start_time;
        printf("AVX-512 implementation: %.6f seconds (%.2fx speedup)\n", 
               avx512_time, scalar_time / avx512_time);
    } else {
        printf("AVX-512 not supported on this CPU\n");
    }
    
    // Print small outputs for verification
    if (output_size <= 8) {
        print_matrix(output_scalar, output_size, output_size, "Output (Scalar)");
        if (check_sse_support()) print_matrix(output_sse, output_size, output_size, "Output (SSE)");
        if (check_avx_support()) print_matrix(output_avx, output_size, output_size, "Output (AVX)");
        if (check_avx2_support()) print_matrix(output_avx2, output_size, output_size, "Output (AVX2)");
        if (check_avx512_support()) print_matrix(output_avx512, output_size, output_size, "Output (AVX-512)");
    }
    
    // Free memory
    free(input);
    free(kernel);
    free(output_scalar);
    free(output_sse);
    free(output_avx);
    free(output_avx2);
    free(output_avx512);
}

int main(int argc, char** argv) {
    printf("SIMD Instruction Set Demo\n");
    printf("-------------------------\n");
    printf("SSE support: %s\n", check_sse_support() ? "Yes" : "No");
    printf("AVX support: %s\n", check_avx_support() ? "Yes" : "No");
    printf("AVX2 support: %s\n", check_avx2_support() ? "Yes" : "No");
    printf("AVX-512 support: %s\n", check_avx512_support() ? "Yes" : "No");
    
    // Test matrix multiplication with different sizes
    test_matrix_multiplication(4);    // Small size for verification
    test_matrix_multiplication(128);  // Medium size
    test_matrix_multiplication(512);  // Large size
    
    // Test convolution with different sizes
    test_convolution(8, 3);     // Small size for verification
    test_convolution(128, 3);   // Medium size
    test_convolution(512, 5);   // Large size
    
    return 0;
}
