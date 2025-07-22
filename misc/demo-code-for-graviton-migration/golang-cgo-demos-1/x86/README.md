# Golang CGO Demonstrations

This project demonstrates three different ways to use CGO (C Go) in a Golang application:

1. **Inline C Code**: C code embedded directly in Go files using special comments
2. **Separate C Files**: C code in separate files that are compiled along with Go code
3. **Shared Library**: Using a pre-compiled shared library (.so file) from Go

## Project Structure

```
golang-cgo-demos-1/x86/
├── Dockerfile        # Docker configuration for building and running
├── Makefile          # Build automation
├── lib/              # Directory for shared libraries
└── src/              # Source code
    ├── inline_cgo.go         # Example 1: Inline C code
    ├── math_ops.c            # C implementation for Example 2
    ├── math_ops.h            # C header for Example 2
    ├── separate_file_cgo.go  # Example 2: Separate C files
    ├── shared_lib_cgo.go     # Example 3: Using shared library
    ├── string_ops.c          # C implementation for shared library
    └── string_ops.h          # C header for shared library
```

## Building and Running

### Using Make

```bash
# Build the project
make build

# Run the application
make run

# Clean up
make clean
```

### Using Docker

```bash
# Build the Docker image
docker build -t golang-cgo-demo .

# Run the container
docker run --rm golang-cgo-demo
```

## Examples Explained

1. **Inline C Code**: The `inline_cgo.go` file contains C code embedded directly in Go using special comments. It demonstrates adding two numbers and creating a greeting message.

2. **Separate C Files**: The `separate_file_cgo.go` file imports functions from `math_ops.c` and `math_ops.h`. It demonstrates multiplication and division operations.

3. **Shared Library**: The `shared_lib_cgo.go` file uses functions from a pre-compiled shared library (`libstringops.so`) through dynamic loading with `dlopen`. It demonstrates string reversal and length calculation. The shared library must be present in the `lib` directory at runtime.

## Notes

- This project is configured to run on x86 architecture.
- CGO must be enabled for this project to work (`CGO_ENABLED=1`).
- When running the application, make sure the shared library is in the library path (`LD_LIBRARY_PATH=./lib`).
