#!/bin/bash

# for ubuntu 24.04

apt update
apt install -y python3-full python3-venv htop screen git curl

# 准备虚拟环境
python3 -m venv ~/aenv-venv
source ~/aenv-venv/bin/activate
pip3 install dool

# x86：安装 AgentENV 和 CLI
curl -fsSL https://raw.githubusercontent.com/kvcache-ai/AgentENV/main/scripts/install.sh | sudo bash
sudo systemctl start aenv

#
aenv auth
# AENV server URL [http://localhost:8000]: http://127.0.0.1:8000
# API key: dummy

# 验证
aenv pull ubuntu:22.04 --name ubuntu
aenv start ubuntu            # starts a sandbox and attaches an interactive shell

# python3 ./aenv_quickstart.py

