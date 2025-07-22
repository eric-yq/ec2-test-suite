#include "string_ops.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// ARM64-specific optimization hints
#ifdef __aarch64__
#include <arm_neon.h>
#endif

// Implementation of the reverse_string function
char* reverse_string(const char* input) {
    printf("C function reverse_string() called with: %s (on ARM64)\n", input);
    
    int len = strlen(input);
    char* result = (char*)malloc(len + 1);
    
    // Basic implementation that works on all architectures
    for (int i = 0; i < len; i++) {
        result[i] = input[len - i - 1];
    }
    result[len] = '\0';
    
    return result;
}

// Implementation of the string_length function
int string_length(const char* input) {
    printf("C function string_length() called with: %s (on ARM64)\n", input);
    
    // For ARM64, we could use NEON instructions for optimized string length calculation
    // in a real-world scenario, but we'll keep it simple for this demo
    return strlen(input);
}
