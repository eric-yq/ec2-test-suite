# Golang CGO Demonstrations for ARM64

This project demonstrates three different ways to use CGO (C Go) in a Golang application, specifically optimized for ARM64 architecture (AWS Graviton3):

1. **Inline C Code**: C code embedded directly in Go files using special comments
2. **Separate C Files**: C code in separate files that are compiled along with Go code
3. **Shared Library**: Using a pre-compiled shared library (.so file) from Go through dynamic loading with `dlopen`

## Project Structure

```
golang-cgo-demos-1/arm64/
├── Dockerfile        # Docker configuration for building and running on ARM64
├── Makefile          # Build automation with ARM64 flags
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

## Building and Running on ARM64 (Graviton3)

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
docker build -t golang-cgo-demo-arm64 .

# Run the container
docker run --rm golang-cgo-demo-arm64
```

## Examples Explained

1. **Inline C Code**: The `inline_cgo.go` file contains C code embedded directly in Go using special comments. It demonstrates adding two numbers and creating a greeting message.

2. **Separate C Files**: The `separate_file_cgo.go` file imports functions from `math_ops.c` and `math_ops.h`. It demonstrates multiplication and division operations.

3. **Shared Library**: The `shared_lib_cgo.go` file uses functions from a pre-compiled shared library (`libstringops.so`) through dynamic loading with `dlopen`. It demonstrates string reversal and length calculation. The shared library must be present in the `lib` directory at runtime.

## Notes

- This project is configured to run on ARM64 architecture, specifically optimized for AWS Graviton3 processors.
- CGO must be enabled for this project to work (`CGO_ENABLED=1`).
- When running the application, make sure the shared library is in the library path (`LD_LIBRARY_PATH=./lib`).
- Cross-compilation is handled by setting `GOARCH=arm64` during the build process.
