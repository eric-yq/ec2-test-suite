# SIMD Instruction Set Demo

This project demonstrates the use of SIMD (Single Instruction, Multiple Data) instructions on x86 architecture, including SSE, AVX, AVX2, and AVX-512. The demo includes implementations of matrix multiplication and convolution operations using different SIMD instruction sets.

## Features

- Implementations of matrix multiplication using:
  - Scalar (non-SIMD) code
  - SSE instructions
  - AVX instructions
  - AVX2 instructions with FMA (Fused Multiply-Add)
  - AVX-512 instructions
  
- Implementations of convolution operations using:
  - Scalar (non-SIMD) code
  - SSE instructions
  - AVX instructions
  - AVX2 instructions with FMA
  - AVX-512 instructions
  
- Performance comparison between different implementations
- Automatic detection of supported instruction sets

## Requirements

- x86 CPU with support for SSE, AVX, AVX2, or AVX-512 instructions
- GCC compiler
- Make

## Building

To build the project, run:

```bash
make
```

The executable will be created in the `build` directory.

## Running

To run the demo:

```bash
make run
```

Or directly:

```bash
./build/simd_demo
```

## Docker

To build and run using Docker:

```bash
# Build the Docker image
docker build -t simd-demo .

# Run the container
docker run --rm simd-demo
```

Note: The Docker container will use the host CPU's instruction set. If your host CPU doesn't support certain SIMD instructions (like AVX-512), those implementations will be skipped.

## CPU Information

To check your CPU's SIMD support:

```bash
make cpu-info
```

## Project Structure

- `include/` - Header files
- `src/` - Source code
  - `main.c` - Main program
  - `matrix_multiply.c` - Matrix multiplication implementations
  - `convolution.c` - Convolution implementations
  - `utils.c` - Utility functions
- `build/` - Build output directory
- `Makefile` - Build configuration
- `Dockerfile` - Docker configuration
