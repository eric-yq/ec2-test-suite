# 演示在 x86 实例上使用 Docker buildx 构建 ARM64 镜像
# EC2 采用 Ubuntu 22.04 环境, 容器采用 centos:8 构建编译机环境

#### 前置条件：准备 Docker buildx 运行环境
# 1. 安装 Docker buildx（如果未安装）
apt update -y
apt install -y docker.io
systemctl start docker
systemctl status docker
systemctl enable docker
#
mkdir -p ~/.docker/cli-plugins
LATEST_VERSION=$(curl -s https://api.github.com/repos/docker/buildx/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
echo "Latest version: $LATEST_VERSION"
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
# 对于某些架构，可能需要映射名称
case $ARCH in
  x86_64)
    ARCH="amd64"
    ;;
  aarch64)
    ARCH="arm64"
    ;;
esac
DOWNLOAD_URL="https://github.com/docker/buildx/releases/download/${LATEST_VERSION}/buildx-${LATEST_VERSION}.${OS}-${ARCH}"
echo "Downloading from: $DOWNLOAD_URL"
curl -L -o  ~/.docker/cli-plugins/docker-buildx $DOWNLOAD_URL
chmod +x ~/.docker/cli-plugins/docker-buildx
ls -l ~/.docker/cli-plugins/docker-buildx

# 2. 启用 QEMU 多架构模拟
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# 3. 创建多架构构建器
docker buildx create --name multiarch --driver docker-container --use
docker buildx inspect --bootstrap

#### 在 x86 实例上构建多架构镜像

##################################################################################################################
# 准备一个Dockerfile 和相关文件 
##################################################################################################################

# 构建多架构镜像（本地缓存）
docker buildx build --platform linux/arm64 -t arm64-builder:latest --load .

### 在 x86 实例上运行 ARM64 容器，并在其中编译代码
docker run -it --rm --privileged arm64-builder:latest /bin/bash

##################################################################################################################
# 在 ARM64 容器中，尝试编译代码
