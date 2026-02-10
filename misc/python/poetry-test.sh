#!/bin/bash

# amazon linux 2023，c8g.xlarge 实例，安装 poetry 和依赖包的脚本

# 安装开发工具包
sudo yum groupinstall "Development Tools" -yq
sudo yum install -y git maven java-17-amazon-corretto-devel

# 安装 conda
curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(arch).sh
bash Miniconda3-latest-Linux-$(arch).sh -b -p $HOME/miniconda3
source $HOME/miniconda3/bin/activate
conda init bash
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# 创建一个 python 3.11 的环境
conda create -n py311 python=3.11 -y
conda activate py311
# conda remove -n py311 --all -y

# 安装 poetry
pip install poetry

# # 将客户的源作为备用
# cp /home/ec2-user/pyproject.toml .
# # poetry source remove nexus
# poetry source add nexus https://nexus.wppopen.cn/repository/wpp-open-libs-python/simple/ --priority=supplemental

# # 将客户的私有依赖包先注释掉，因为在pypi 找不到
# # wpp-core-kit = {extras = ["notifications", "markdown"], version = "0.3.3+china1"}
# # wpp-core-logging = "^0.1.1"
# # object-storage-sdk-python = "0.4.1+chinap2"
# # az-auth = "~1.0.12"

#########################################################################
## 先安装 psycopg2-binary 的依赖包
sudo yum install -y postgresql-devel gcc python3-devel
#########################################################################
# 私有包先不安装 wpp-core-kit, wpp-core-logging, object-storage-sdk-python, az-auth
# 只验证Pypi 上公有的依赖包：
cat > pyproject.toml << EOF
[tool.poetry]
name = "notification-api"
version = "0.1.0"
description = "test"
authors = []

[tool.poetry.dependencies]
python = "^3.11"
sendgrid = "^6.9.7"
Jinja2 = "^3.1.2"
pydantic = {version = "^1.10.14", extras = ["email"]}
httpx = "^0.27.0"
python-dotenv = "^0.20.0"
PyYAML = "^6.0"
google-cloud-pubsub = "^2.17.1"
dependency-injector = "^4.41.0"
sqlalchemy = {version = "^2.0.13", extras = ["postgresql", "postgresql-asyncpg"]}
alembic = "^1.11.1"
fastapi = "^0.98.0"
uvicorn = "^0.22.0"
gcloud-aio-storage = "^9.0.0"
cairosvg = "^2.7.1"
aiohttp = "^3.9.3"
alibabacloud-dm20151123 = "^1.7.2"
alibabacloud-credentials = "^1.0.4"
alibabacloud-tea-openapi = "^0.4.2"
alibabacloud-tea-util = "^0.3.14"
psycopg2-binary = "^2.9.9"

[tool.poetry.group.dev.dependencies]
flake8 = "^4.0.1"
flake8-bugbear = "^22.3.20"
flake8-bandit = "^3.0.0"
flake8-annotations-complexity = "^0.0.7"
flake8-commas = "^2.1.0"
flake8-quotes = "^3.3.1"
flake8-isort = "^4.1.1"
pep8-naming = "^0.12.1"
flake8-eradicate = "^1.2.0"
mypy = "^1.3.0"
black = "^22.1.0"
pytest = "^7.1.1"
pytest-asyncio = "^0.21.0"
pytest-cov = "^3.0.0"
pytest-mock = "^3.10.0"
pyproject-flake8 = "^0.0.1-alpha.4"
factory-boy = "^3.2.1"
PyJWT = "^2.3.0"
debugpy = "^1.6.2"
types-PyYAML = "^6.0.11"
pytest-alembic = "^0.8.3"
respx = "^0.20.1"
faker-enum = "^0.0.2"
asgi-lifespan = "^2.1.0"

[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"
EOF

# 安装
poetry install --no-root

## 只下载包，不安装
# 安装插件
poetry self add poetry-plugin-export

# 检查 pyproject.toml 是否存在
if [ ! -f "pyproject.toml" ]; then
    echo "错误: 当前目录没有 pyproject.toml 文件"
    echo "当前目录: $(pwd)"
    exit 1
fi

echo "找到 pyproject.toml，开始导出依赖..."

# 导出依赖（会自动读取当前目录的 pyproject.toml）
poetry export -f requirements.txt --output requirements.txt --without-hashes
poetry export -f requirements.txt --output requirements-dev.txt --with dev --without-hashes

echo "导出完成！"

# 下载
mkdir -p arm-packages
pip download --dest arm-packages -r requirements.txt
pip download --dest arm-packages -r requirements-dev.txt