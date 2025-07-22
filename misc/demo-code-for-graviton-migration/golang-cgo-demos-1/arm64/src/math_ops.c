#include "math_ops.h"
#include <stdio.h>

// ARM64-specific optimization hints
#ifdef __aarch64__
// ARM64-specific includes would go here if needed
#endif

// Implementation of the multiply function
double multiply(double a, double b) {
    printf("C function multiply() called with %f and %f (on ARM64)\n", a, b);
    return a * b;
}

// Implementation of the divide function
double divide(double a, double b) {
    printf("C function divide() called with %f and %f (on ARM64)\n", a, b);
    if (b == 0) {
        printf("Error: Division by zero! (on ARM64)\n");
        return 0;
    }
    return a / b;
}
