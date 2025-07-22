package main

import "C" // This imports the C pseudo-package
import (
	"fmt"
	"unsafe"
)

// Example 1: Inline C code in Go using comments
// The C code is embedded directly in the Go file using special comments

/*
#include <stdio.h>
#include <stdlib.h>

// Check for ARM64 architecture
#ifdef __aarch64__
#define ARCH_MSG " (on ARM64)"
#else
#define ARCH_MSG ""
#endif

// A simple C function that adds two integers
int add(int a, int b) {
    printf("C function add() called with %d and %d%s\n", a, b, ARCH_MSG);
    return a + b;
}

// A function that returns a string
char* greet(const char* name) {
    char* result = (char*)malloc(100);
    sprintf(result, "Hello, %s from C%s!", name, ARCH_MSG);
    return result;
}
*/
import "C" // This must appear directly after the comment block

func main() {
	fmt.Println("=== CGO Demo: Three different ways to use CGO (ARM64 Version) ===")
	
	fmt.Println("\n=== Example 1: Inline C code ===")
	
	// Call the C function add
	result := C.add(C.int(10), C.int(20))
	fmt.Printf("Result from C add function: %d\n", int(result))
	
	// Call the C function greet
	name := C.CString("Gopher")
	defer C.free(unsafe.Pointer(name)) // Important: free the C allocated memory
	
	greeting := C.greet(name)
	defer C.free(unsafe.Pointer(greeting)) // Free the string allocated by C
	
	// Convert C string to Go string
	goGreeting := C.GoString(greeting)
	fmt.Println(goGreeting)
	
	// Call the other examples
	exampleSeparateFile()
	exampleSharedLibrary()
}
