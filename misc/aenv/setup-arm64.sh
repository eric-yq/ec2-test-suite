#!/bin/bash

# for ubuntu 24.04, root user

apt update
apt install -y python3-full python3-venv htop screen git curl 
apt install -y build-essential
apt install -y docker.io
systemctl enable --now docker
mkdir -p ~/.docker/cli-plugins
curl -sL https://github.com/docker/buildx/releases/download/v0.14.1/buildx-v0.14.1.linux-arm64 -o ~/.docker/cli-plugins/docker-buildx
chmod +x ~/.docker/cli-plugins/docker-buildx
docker buildx version

# 准备虚拟环境
# python3 -m venv ~/aenv-venv
# source ~/aenv-venv/bin/activate
# pip3 install dool

#####################################################################################################
## 创建 aenv 用户和组
# 创建用户组
groupadd aenv
# 创建用户，加入 aenv 组，带 home 目录
useradd -m -g aenv -s /bin/bash aenv
# 给 sudo 权限（免密）
echo "aenv ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/aenv
chmod 440 /etc/sudoers.d/aenv
# 验证
su - aenv -c "sudo whoami"
# 输出: root

# 下载 aarch64 的 firecracker
mkdir -p /var/lib/aenv/deps/firecracker/1.15.1-patch-v1/
mkdir -p /var/lib/aenv/deps/kernel/vmlinux-6.1.175/
cd /tmp
# 1. Firecracker
wget https://github.com/kvcache-ai/firecracker/releases/download/v0.1.0/firecracker-1.15.1-patch-v1-aarch64.tgz
tar -xzf firecracker-1.15.1-patch-v1-aarch64.tgz
ls -la
cp firecracker /var/lib/aenv/deps/firecracker/1.15.1-patch-v1/firecracker
chmod +x /var/lib/aenv/deps/firecracker/1.15.1-patch-v1/firecracker
# 2. Kernel
wget https://github.com/kvcache-ai/firecracker/releases/download/v0.1.0/vmlinux-6.1.175-aarch64
cp vmlinux-6.1.175-aarch64 /var/lib/aenv/deps/kernel/vmlinux-6.1.175/vmlinux.bin
# 3. 确认架构
file /var/lib/aenv/deps/firecracker/1.15.1-patch-v1/firecracker
file /var/lib/aenv/deps/kernel/vmlinux-6.1.175/vmlinux.bin

# arm64：编译 aenv-server
cd
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env
rustc --version   # 需要 >= 1.85
cargo --version
apt install -y libssl-dev pkg-config clang lld protobuf-compiler umoci
# 编译 AgentENV
git clone https://github.com/kvcache-ai/AgentENV.git
cd AgentENV
ulimit -n 65536
make release


# 构建 aarch64 架构的 tools.ext4
cd ~/AgentENV/tools-image/
sed -i.bak \
  's|ARG TARGETPLATFORM=linux/amd64|ARG TARGETPLATFORM=linux/arm64|' \
  Dockerfile
make
mkdir -p /var/lib/aenv/deps/tools/0.1.0/
cp out/tools-0.1.0-arm64.ext4 /var/lib/aenv/deps/tools/0.1.0/tools.ext4

# 
cd ~/AgentENV/
mkdir -p /var/lib/aenv/deps/overlaybd/etc/overlaybd
mkdir -p /var/lib/aenv/cache/overlaybd
cat > /var/lib/aenv/deps/overlaybd/etc/overlaybd/overlaybd.json << 'EOF'
{
    "logLevel": 1,
    "logPath": "/var/log/overlaybd.log",
    "cacheConfig": {
        "cachePath": "/var/lib/aenv/cache/overlaybd",
        "cacheSize": 10737418240
    },
    "download": {
        "maxConcurrency": 16,
        "blockSize": 262144
    }
}
EOF
./target/release/server --setup-host

API_ADDR=0.0.0.0:8000 make start-server-release &
netstat -anp|grep 8000

######################################################################################################

# 安装 CLI
curl -fsSL https://raw.githubusercontent.com/kvcache-ai/AgentENV/main/scripts/install-cli.sh | bash
# 
aenv auth
# AENV server URL [http://localhost:8000]: http://127.0.0.1:8000
# API key: dummy

# 验证
aenv pull ubuntu:22.04 --name ubuntu
aenv start ubuntu            # starts a sandbox and attaches an interactive shell



