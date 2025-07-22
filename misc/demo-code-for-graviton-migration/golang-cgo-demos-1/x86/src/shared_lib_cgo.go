package main

// Example 3: Using a pre-compiled shared library

/*
#cgo LDFLAGS: -ldl
#include <stdlib.h>
#include <dlfcn.h>
#include <stdio.h>

char* reverse_string_dynamic(const char* input) {
    void* handle = dlopen("./lib/libstringops.so", RTLD_LAZY);
    if (!handle) {
        fprintf(stderr, "Error loading library: %s\n", dlerror());
        return NULL;
    }
    
    char* (*func)(const char*);
    *(void **)(&func) = dlsym(handle, "reverse_string");
    
    char* result = NULL;
    if (func) {
        result = func(input);
    } else {
        fprintf(stderr, "Error finding function: %s\n", dlerror());
    }
    
    // Note: We don't close the handle with dlclose() because the result 
    // pointer is allocated by the library and would be invalid after dlclose
    return result;
}

int string_length_dynamic(const char* input) {
    void* handle = dlopen("./lib/libstringops.so", RTLD_LAZY);
    if (!handle) {
        fprintf(stderr, "Error loading library: %s\n", dlerror());
        return -1;
    }
    
    int (*func)(const char*);
    *(void **)(&func) = dlsym(handle, "string_length");
    
    int result = -1;
    if (func) {
        result = func(input);
    } else {
        fprintf(stderr, "Error finding function: %s\n", dlerror());
    }
    
    dlclose(handle);
    return result;
}
*/
import "C"
import (
	"fmt"
	"unsafe"
)

func exampleSharedLibrary() {
	fmt.Println("\n=== Example 3: Using a pre-compiled shared library ===")
	
	// Call the reverse_string function from the shared library
	input := C.CString("Hello from Go!")
	defer C.free(unsafe.Pointer(input))
	
	reversed := C.reverse_string_dynamic(input)
	if reversed == nil {
		fmt.Println("Error: Could not load shared library or function")
		return
	}
	defer C.free(unsafe.Pointer(reversed))
	
	goReversed := C.GoString(reversed)
	fmt.Printf("Original string: %s\n", "Hello from Go!")
	fmt.Printf("Reversed string: %s\n", goReversed)
	
	// Call the string_length function from the shared library
	length := C.string_length_dynamic(input)
	if int(length) == -1 {
		fmt.Println("Error: Could not load shared library or function")
		return
	}
	fmt.Printf("String length: %d\n", int(length))
}
