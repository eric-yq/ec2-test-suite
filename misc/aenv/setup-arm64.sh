#!/bin/bash

# for ubuntu 24.04, root user

apt update
apt install -y python3-full python3-venv htop screen git curl 
apt install -y build-essential
apt install -y docker.io
systemctl enable --now docker

# 准备虚拟环境
python3 -m venv ~/aenv-venv
source ~/aenv-venv/bin/activate
pip3 install dool

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

#
# kvcache-ai/firecracker 编译构建 aarch64 版本
# https://github.com/kvcache-ai/firecracker 
git clone https://github.com/firecracker-microvm/firecracker
cd firecracker
tools/devtool build
toolchain="$(uname -m)-unknown-linux-musl"
ll build/cargo_target/${toolchain}/debug/firecracker
mkdir -p /var/lib/aenv/deps/firecracker/1.15.1-patch-v1/
cp ~/firecracker/build/cargo_target/aarch64-unknown-linux-musl/debug/firecracker \
   /var/lib/aenv/deps/firecracker/1.15.1-patch-v1/firecracker

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
make release

# 
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




python3 ./aenv_quickstart.py

