#!/bin/bash

# Build script for both x86 and ARM64 architectures

# Build x86 version
echo "Building x86 version..."
cd /root/golang-cgo-demos-1/x86
make clean
make build

# Build ARM64 version
echo "Building ARM64 version..."
cd /root/golang-cgo-demos-1/arm64
make clean
make build

echo "Build complete!"
echo "To run the x86 version: cd /root/golang-cgo-demos-1/x86 && ./cgo-demo"
echo "To run the ARM64 version (on Graviton3): cd /root/golang-cgo-demos-1/arm64 && ./cgo-demo"
