#include "../include/simd_utils.h"

void test_matrix_multiplication(int size) {
    printf("\n===== Testing Matrix Multiplication (%dx%d) =====\n", size, size);
    
    // Allocate memory for matrices
    float* A = (float*)aligned_alloc(16, size * size * sizeof(float));
    float* B = (float*)aligned_alloc(16, size * size * sizeof(float));
    float* C_scalar = (float*)aligned_alloc(16, size * size * sizeof(float));
    float* C_neon = (float*)aligned_alloc(16, size * size * sizeof(float));
    float* C_sve = (float*)aligned_alloc(16, size * size * sizeof(float));
    float* C_sve2 = (float*)aligned_alloc(16, size * size * sizeof(float));
    
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
    
    // Test NEON implementation if supported
    if (check_neon_support()) {
        start_time = get_time();
        matrix_multiply_neon(A, B, C_neon, size, size, size);
        double neon_time = get_time() - start_time;
        printf("NEON implementation: %.6f seconds (%.2fx speedup)\n", 
               neon_time, scalar_time / neon_time);
    } else {
        printf("NEON not supported on this CPU\n");
    }
    
    // Test SVE implementation if supported
    if (check_sve_support()) {
        start_time = get_time();
        matrix_multiply_sve(A, B, C_sve, size, size, size);
        double sve_time = get_time() - start_time;
        printf("SVE implementation: %.6f seconds (%.2fx speedup)\n", 
               sve_time, scalar_time / sve_time);
    } else {
        printf("SVE not supported on this CPU\n");
    }
    
    // Test SVE2 implementation if supported
    if (check_sve2_support()) {
        start_time = get_time();
        matrix_multiply_sve2(A, B, C_sve2, size, size, size);
        double sve2_time = get_time() - start_time;
        printf("SVE2 implementation: %.6f seconds (%.2fx speedup)\n", 
               sve2_time, scalar_time / sve2_time);
    } else {
        printf("SVE2 not supported on this CPU\n");
    }
    
    // Print small result matrices for verification
    if (size <= 8) {
        print_matrix(C_scalar, size, size, "Result (Scalar)");
        if (check_neon_support()) print_matrix(C_neon, size, size, "Result (NEON)");
        if (check_sve_support()) print_matrix(C_sve, size, size, "Result (SVE)");
        if (check_sve2_support()) print_matrix(C_sve2, size, size, "Result (SVE2)");
    }
    
    // Free memory
    free(A);
    free(B);
    free(C_scalar);
    free(C_neon);
    free(C_sve);
    free(C_sve2);
}

void test_convolution(int input_size, int kernel_size) {
    printf("\n===== Testing Convolution (Input: %dx%d, Kernel: %dx%d) =====\n", 
           input_size, input_size, kernel_size, kernel_size);
    
    int output_size = input_size - kernel_size + 1;
    
    // Allocate memory
    float* input = (float*)aligned_alloc(16, input_size * input_size * sizeof(float));
    float* kernel = (float*)aligned_alloc(16, kernel_size * kernel_size * sizeof(float));
    float* output_scalar = (float*)aligned_alloc(16, output_size * output_size * sizeof(float));
    float* output_neon = (float*)aligned_alloc(16, output_size * output_size * sizeof(float));
    float* output_sve = (float*)aligned_alloc(16, output_size * output_size * sizeof(float));
    float* output_sve2 = (float*)aligned_alloc(16, output_size * output_size * sizeof(float));
    
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
    
    // Test NEON implementation if supported
    if (check_neon_support()) {
        start_time = get_time();
        convolution_neon(input, kernel, output_neon, input_size, input_size, kernel_size);
        double neon_time = get_time() - start_time;
        printf("NEON implementation: %.6f seconds (%.2fx speedup)\n", 
               neon_time, scalar_time / neon_time);
    } else {
        printf("NEON not supported on this CPU\n");
    }
    
    // Test SVE implementation if supported
    if (check_sve_support()) {
        start_time = get_time();
        convolution_sve(input, kernel, output_sve, input_size, input_size, kernel_size);
        double sve_time = get_time() - start_time;
        printf("SVE implementation: %.6f seconds (%.2fx speedup)\n", 
               sve_time, scalar_time / sve_time);
    } else {
        printf("SVE not supported on this CPU\n");
    }
    
    // Test SVE2 implementation if supported
    if (check_sve2_support()) {
        start_time = get_time();
        convolution_sve2(input, kernel, output_sve2, input_size, input_size, kernel_size);
        double sve2_time = get_time() - start_time;
        printf("SVE2 implementation: %.6f seconds (%.2fx speedup)\n", 
               sve2_time, scalar_time / sve2_time);
    } else {
        printf("SVE2 not supported on this CPU\n");
    }
    
    // Print small outputs for verification
    if (output_size <= 8) {
        print_matrix(output_scalar, output_size, output_size, "Output (Scalar)");
        if (check_neon_support()) print_matrix(output_neon, output_size, output_size, "Output (NEON)");
        if (check_sve_support()) print_matrix(output_sve, output_size, output_size, "Output (SVE)");
        if (check_sve2_support()) print_matrix(output_sve2, output_size, output_size, "Output (SVE2)");
    }
    
    // Free memory
    free(input);
    free(kernel);
    free(output_scalar);
    free(output_neon);
    free(output_sve);
    free(output_sve2);
}

int main(int argc, char** argv) {
    printf("ARM SIMD Instruction Set Demo\n");
    printf("-----------------------------\n");
    printf("NEON support: %s\n", check_neon_support() ? "Yes" : "No");
    printf("SVE support: %s\n", check_sve_support() ? "Yes" : "No");
    printf("SVE2 support: %s\n", check_sve2_support() ? "Yes" : "No");
    
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
