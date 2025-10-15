##### 内核太老，后面很多问题！

# 使用 centos7 的 AMI，启动 c6i.xlarge 实例

# 停止 Docker 服务
sudo systemctl stop docker

# 卸载旧版 Docker 包
sudo yum remove -y docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine \
                  docker-current

# 安装必要的软件包
sudo yum install -y yum-utils device-mapper-persistent-data lvm2

# 添加 Docker 仓库
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# 安装 Docker
sudo yum install -y docker-ce docker-ce-cli containerd.io

# 启动 Docker 服务
sudo systemctl start docker
sudo systemctl enable docker

# 验证 Docker 安装
docker --version

#####################################################################################################
# 安装 EPEL 仓库
sudo yum install -y epel-release

# 安装 QEMU 和相关工具
sudo yum install -y qemu qemu-user-static binfmt-support

#####################################################################################################
# 编辑 Docker 配置文件
cat << EOF > /etc/docker/daemon.json
# 添加以下内容
{
  "experimental": true
}
EOF
cat /etc/docker/daemon.json

# 重启 Docker 服务
sudo systemctl restart docker

# 使用 Docker 的实验性功能启用 qemu
docker run --privileged --rm tonistiigi/binfmt --install arm64
#####################################################################################################

echo "===== 注册 QEMU 二进制格式处理程序 ====="
sudo docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

echo "===== 手动设置 binfmt 支持 ====="
echo ':qemu-aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7:\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff:/usr/bin/qemu-aarch64-static:' | sudo tee /proc/sys/fs/binfmt_misc/register || echo "已经注册或注册失败，继续..."

echo "===== 安装 Docker BuildX ====="
mkdir -p ~/.docker/cli-plugins/
BUILDX_VERSION=$(curl -s https://api.github.com/repos/docker/buildx/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
curl -L "https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-amd64" -o ~/.docker/cli-plugins/docker-buildx
chmod +x ~/.docker/cli-plugins/docker-buildx

echo "===== 设置 Docker BuildX 构建器 ====="
docker buildx create --name arm64-builder --use || echo "构建器可能已存在"
docker buildx inspect --bootstrap

echo "===== 使用 Dockerfile 构建 ARM64 镜像 ====="
# 替换为您的 Dockerfile 路径
DOCKERFILE_PATH="./Dockerfile"
docker buildx build --platform linux/arm64 -t arm64-builder:latest -f $DOCKERFILE_PATH --load .

echo "===== 验证镜像架构 ====="
docker inspect arm64-builder:latest | grep Architecture

echo "===== 运行 ARM64 容器 ====="
docker run -it --rm --platform=linux/arm64 arm64-builder:latest uname -m

echo "===== 完成! ====="
echo "现在您可以使用以下命令运行交互式 ARM64 容器："
echo "docker run -it --rm --platform=linux/arm64 arm64-builder:latest /bin/bash"
