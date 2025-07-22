#include "string_ops.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Implementation of the reverse_string function
char* reverse_string(const char* input) {
    printf("C function reverse_string() called with: %s\n", input);
    
    int len = strlen(input);
    char* result = (char*)malloc(len + 1);
    
    for (int i = 0; i < len; i++) {
        result[i] = input[len - i - 1];
    }
    result[len] = '\0';
    
    return result;
}

// Implementation of the string_length function
int string_length(const char* input) {
    printf("C function string_length() called with: %s\n", input);
    return strlen(input);
}
