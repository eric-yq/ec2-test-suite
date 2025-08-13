#!/bin/bash

# Docker Build Script for Java Native Demo (x86_64 only)

set -e

echo "=== Docker Build Script ==="
echo "Architecture: $(uname -m)"

# 检查架构
if [ "$(uname -m)" != "x86_64" ]; then
    echo "ERROR: This Docker image only supports x86_64 architecture"
    echo "Current architecture: $(uname -m)"
    exit 1
fi

# 检查 Docker 是否可用
command -v docker >/dev/null 2>&1 || { 
    echo "ERROR: Docker is required but not installed"; 
    exit 1; 
}

# 镜像名称和标签
IMAGE_NAME="java-native-demo"
IMAGE_TAG="x86_64-latest"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

echo "Building Docker image: $FULL_IMAGE_NAME"
echo ""

# 构建 Docker 镜像
docker build \
    --platform linux/amd64 \
    --tag "$FULL_IMAGE_NAME" \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    .

echo ""
echo "=== Docker build completed successfully ==="
echo "Image: $FULL_IMAGE_NAME"
echo ""
echo "To run the container:"
echo "  docker run --rm $FULL_IMAGE_NAME"
echo ""
echo "To run interactively:"
echo "  docker run --rm -it $FULL_IMAGE_NAME /bin/bash"
echo ""
echo "To check image details:"
echo "  docker images $IMAGE_NAME"
echo "  docker inspect $FULL_IMAGE_NAME"
