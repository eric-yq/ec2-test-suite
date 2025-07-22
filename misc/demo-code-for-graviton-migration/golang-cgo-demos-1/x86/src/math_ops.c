#include "math_ops.h"
#include <stdio.h>

// Implementation of the multiply function
double multiply(double a, double b) {
    printf("C function multiply() called with %f and %f\n", a, b);
    return a * b;
}

// Implementation of the divide function
double divide(double a, double b) {
    printf("C function divide() called with %f and %f\n", a, b);
    if (b == 0) {
        printf("Error: Division by zero!\n");
        return 0;
    }
    return a / b;
}
