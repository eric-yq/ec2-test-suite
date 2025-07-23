# SIMD Instruction Set Demo for ARM64

This project demonstrates the use of SIMD (Single Instruction, Multiple Data) instructions on ARM64 architecture, including NEON, SVE, and SVE2. The demo includes implementations of matrix multiplication and convolution operations using different SIMD instruction sets.

## Features

- Implementations of matrix multiplication using:
  - Scalar (non-SIMD) code
  - NEON instructions (128-bit vectors)
  - SVE instructions (scalable vector length)
  - SVE2 instructions (enhanced SVE)
  
- Implementations of convolution operations using:
  - Scalar (non-SIMD) code
  - NEON instructions
  - SVE instructions
  - SVE2 instructions
  
- Performance comparison between different implementations
- Automatic detection of supported instruction sets

## Requirements

- ARM64 (AArch64) CPU with support for NEON (mandatory in ARMv8), SVE, or SVE2
- GCC compiler with ARM64 support
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

Note: The Docker container will use the host CPU's instruction set. If your host CPU doesn't support certain SIMD instructions (like SVE or SVE2), those implementations will be skipped.

## CPU Information

To check your CPU's SIMD support:

```bash
make cpu-info
```

## SIMD Instruction Sets

### NEON
- 128-bit SIMD architecture extension for ARMv8
- Mandatory in all ARMv8-A implementations
- Provides 32 128-bit registers (Q0-Q31)

### SVE (Scalable Vector Extension)
- Vector length agnostic programming model
- Vector length can be any multiple of 128 bits, up to 2048 bits
- Introduced in ARMv8.2-A

### SVE2
- Enhanced version of SVE
- Adds additional instructions for machine learning and DSP
- Introduced in ARMv8.6-A

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
