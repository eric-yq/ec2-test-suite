# SIMD Instruction Set Demo for ARM64 with SIMDe

This project demonstrates the use of SIMD (Single Instruction, Multiple Data) instructions on ARM64 architecture using SIMDe (SIMD Everywhere) to emulate x86 SIMD instructions. The demo includes implementations of matrix multiplication and convolution operations using different SIMD instruction sets that are translated to ARM NEON instructions.

## Features

- Implementations of matrix multiplication using:
  - Scalar (non-SIMD) code
  - SSE instructions (emulated via SIMDe)
  - AVX instructions (emulated via SIMDe)
  - AVX2 instructions with FMA (emulated via SIMDe)
  - AVX-512 instructions (emulated via SIMDe)
  
- Implementations of convolution operations using:
  - Scalar (non-SIMD) code
  - SSE instructions (emulated via SIMDe)
  - AVX instructions (emulated via SIMDe)
  - AVX2 instructions with FMA (emulated via SIMDe)
  - AVX-512 instructions (emulated via SIMDe)
  
- Performance comparison between different implementations
- Optimized for AWS Graviton4 processors

## About SIMDe

SIMDe (SIMD Everywhere) is a header-only library that provides implementations of SIMD instruction sets for systems which don't natively support them. It translates x86 SIMD instructions to equivalent ARM NEON instructions, allowing x86 SIMD code to run on ARM processors.

## Requirements

- ARM64 CPU with NEON support (like AWS Graviton4)
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
docker build -t simd-demo-arm64 .

# Run the container
docker run --rm simd-demo-arm64
```

## CPU Information

To check your CPU's SIMD support:

```bash
make cpu-info
```

## Project Structure

- `include/` - Header files
- `simde/` - SIMDe library headers
- `src/` - Source code
  - `main.c` - Main program
  - `matrix_multiply.c` - Matrix multiplication implementations
  - `convolution.c` - Convolution implementations
  - `utils.c` - Utility functions
- `build/` - Build output directory
- `Makefile` - Build configuration
- `Dockerfile` - Docker configuration
