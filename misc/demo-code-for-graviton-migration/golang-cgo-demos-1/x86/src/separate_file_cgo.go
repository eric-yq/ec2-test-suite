package main

// Example 2: C code in separate files

/*
#include "math_ops.h"
*/
import "C"
import "fmt"

func exampleSeparateFile() {
	fmt.Println("\n=== Example 2: C code in separate files ===")
	
	// Call the multiply function from math_ops.c
	result1 := C.multiply(C.double(5.5), C.double(2.5))
	fmt.Printf("Result from C multiply function: %f\n", float64(result1))
	
	// Call the divide function from math_ops.c
	result2 := C.divide(C.double(10.0), C.double(2.0))
	fmt.Printf("Result from C divide function: %f\n", float64(result2))
}
