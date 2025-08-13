#!/bin/bash

# Docker Multi-Architecture Build Script for Java Native Demo

set -e

echo "=== Docker Multi-Architecture Build Script ==="
echo "Current Architecture: $(uname -m)"

# 检查 Docker 是否可用
command -v docker >/dev/null 2>&1 || { 
    echo "ERROR: Docker is required but not installed"; 
    exit 1; 
}

# 镜像名称和标签
IMAGE_NAME="java-native-demo-multiarch"
IMAGE_TAG="latest"

echo "Building Docker images for multiple architectures..."
echo "Image base name: $IMAGE_NAME"
echo ""

# 方法1: 使用 Docker Buildx 构建多架构镜像（推荐）
if docker buildx version >/dev/null 2>&1; then
    echo "Using Docker Buildx for multi-architecture build..."
    
    # 创建并使用新的 builder 实例（如果不存在）
    BUILDER_NAME="multiarch-builder"
    if ! docker buildx ls | grep -q "$BUILDER_NAME"; then
        echo "Creating new buildx builder: $BUILDER_NAME"
        docker buildx create --name "$BUILDER_NAME" --driver docker-container --bootstrap
    fi
    
    echo "Using buildx builder: $BUILDER_NAME"
    docker buildx use "$BUILDER_NAME"
    
    # 构建多架构镜像并加载到本地
    echo "Building multi-architecture images..."
    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        --tag "${IMAGE_NAME}:${IMAGE_TAG}" \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        .
    
    # 分别构建并加载到本地用于测试
    echo "Building and loading x86_64 image..."
    docker buildx build \
        --platform linux/amd64 \
        --tag "${IMAGE_NAME}:x86_64-${IMAGE_TAG}" \
        --load \
        .
    
    echo "Building and loading ARM64 image..."
    docker buildx build \
        --platform linux/arm64 \
        --tag "${IMAGE_NAME}:arm64-${IMAGE_TAG}" \
        --load \
        .
    
    echo ""
    echo "=== Buildx multi-architecture build completed ==="
    
else
    # 方法2: 传统方式分别构建（如果没有 Buildx）
    echo "Docker Buildx not available, using traditional build method..."
    
    # 构建当前架构的镜像
    CURRENT_ARCH=$(uname -m)
    if [ "$CURRENT_ARCH" = "x86_64" ]; then
        DOCKER_ARCH="amd64"
    elif [ "$CURRENT_ARCH" = "aarch64" ]; then
        DOCKER_ARCH="arm64"
    else
        echo "ERROR: Unsupported architecture: $CURRENT_ARCH"
        exit 1
    fi
    
    echo "Building image for current architecture: $DOCKER_ARCH"
    docker build \
        --tag "${IMAGE_NAME}:${DOCKER_ARCH}-${IMAGE_TAG}" \
        --tag "${IMAGE_NAME}:${IMAGE_TAG}" \
        .
    
    echo ""
    echo "=== Traditional build completed for $DOCKER_ARCH ==="
fi

echo ""
echo "Available images:"
docker images | grep "$IMAGE_NAME"

echo ""
echo "To run the container:"
echo "  docker run --rm ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
echo "To run interactively:"
echo "  docker run --rm -it ${IMAGE_NAME}:${IMAGE_TAG} /bin/bash"
echo ""
echo "To test specific architecture (if built with Buildx):"
echo "  docker run --rm ${IMAGE_NAME}:x86_64-${IMAGE_TAG}"
echo "  docker run --rm ${IMAGE_NAME}:arm64-${IMAGE_TAG}"
