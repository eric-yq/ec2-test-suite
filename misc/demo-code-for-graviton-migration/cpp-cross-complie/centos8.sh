## CentOS 8 先更新 repo 文件
mkdir  /etc/yum.repos.d/back/ && \
mv  /etc/yum.repos.d/*.repo  /etc/yum.repos.d/back/
cp /home/centos/CentOS-Base-8.4.2105.repo /etc/yum.repos.d/
yum clean all
yum makecache

## 安装 Docker
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io
sudo systemctl start docker
sudo systemctl enable docker
docker --version

## 安装 Qemu 和相关工具
sudo yum install -y epel-release
yum install -y qemu-kvm qemu-img

## 安装docker buildx 相关
echo "===== 安装 Docker BuildX ====="
mkdir -p ~/.docker/cli-plugins/
BUILDX_VERSION=$(curl -s https://api.github.com/repos/docker/buildx/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
curl -L "https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-amd64" -o ~/.docker/cli-plugins/docker-buildx
chmod +x ~/.docker/cli-plugins/docker-buildx
ls -l ~/.docker/cli-plugins/docker-buildx

## 配置 Docker 支持多架构
echo "===== 配置 Docker 支持多架构 ====="
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
docker buildx create --name multiarch --driver docker-container --use
docker buildx inspect --bootstrap

# 验证
docker run --rm --platform=linux/arm64 arm64v8/debian:bullseye-slim uname -m

# 看是否需要修改 Dockerfile
mkdir cloud
cd cloud/
cp /home/centos/* .
cp Dockerfile-for-build-host.sh  Dockerfile
vi Dockerfile

# 构建镜像
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


#####################################################################################################
# 容器内验证 C/C++ 程序编译
docker run -it --rm --platform=linux/arm64 arm64-builder:latest /bin/bash

# 样例 1：bRPC 1.4
cd 
ver=1.4.0
wget https://github.com/apache/brpc/archive/refs/tags/$ver.tar.gz
tar zxf $ver.tar.gz
cd brpc-$ver
sh config_brpc.sh --headers="/usr/include" --libs="/usr/lib64 /usr/bin"
make -j 3

# 样例 2：libcryptopp
cd
wget https://github.com/weidai11/cryptopp/archive/refs/tags/CRYPTOPP_8_3_0.tar.gz
tar zxf CRYPTOPP_8_3_0.tar.gz
cd  cryptopp-CRYPTOPP_8_3_0
make -j 3 libcryptopp.so
make -j 3 libcryptopp.a
ls -l libcryptopp*  

# 样例 3：oneTBB
cd 
wget https://github.com/uxlfoundation/oneTBB/archive/refs/tags/v2021.5.0.tar.gz
tar zxf v2021.5.0.tar.gz
cd oneTBB-2021.5.0
## 编译样例
mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/root/my_installed_onetbb -DTBB_TEST=OFF ..
cmake --build .
cmake --install .
## 验证
# [root@f175dbf77311 build]#  ls -l /root/my_installed_onetbb/*