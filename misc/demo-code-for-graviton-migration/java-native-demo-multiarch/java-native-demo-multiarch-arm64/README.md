# Java Native Demo Multi-Architecture

这是一个演示 Java 应用程序与 native libraries 集成的项目，包含第三方组件的使用和自定义 native library 的调用。本项目支持**真正的多架构部署**，单个 JAR 包可以在 x86_64 和 ARM64 系统上无缝运行。

## 🎯 核心特性

### 多架构支持
- **🔄 单一 JAR 包**: 一个 JAR 包支持多个架构
- **🤖 自动检测**: 运行时自动检测系统架构
- **📦 内嵌库**: Native libraries 完全内嵌在 JAR 包中
- **🔧 智能加载**: 自动选择对应架构的 native libraries

### 支持的架构
- **x86_64 (AMD64)**: Intel/AMD 64位处理器 ✅
- **ARM64 (AArch64)**: ARM 64位处理器，包括 AWS Graviton ✅

## 📁 项目结构

```
java-native-demo-multiarch-arm64/
├── src/
│   └── main/
│       ├── java/com/example/demo/
│       │   ├── NativeDemoApplication.java    # 主应用程序
│       │   ├── NativeLibraryLoader.java      # 多架构 native library 加载器
│       │   ├── MathUtils.java                # 数学工具类
│       │   ├── StringUtils.java              # 字符串工具类
│       │   ├── SystemInfo.java               # 系统信息类
│       │   └── ThirdPartyDemo.java           # 第三方组件演示
│       ├── cpp/
│       │   ├── mathutils.cpp                 # 数学工具 native 实现
│       │   ├── stringutils.cpp               # 字符串工具 native 实现
│       │   └── systeminfo.cpp                # 系统信息 native 实现
│       └── resources/
│           └── native/                       # 多架构 native libraries
│               ├── linux-x86_64/             # x86_64 架构的 .so 文件
│               └── linux-aarch64/            # ARM64 架构的 .so 文件
├── target/
│   ├── java-native-demo-multiarch-1.0.0.jar  # 多架构 JAR 包
│   └── native/                               # 编译后的 .so 文件
│       ├── linux-x86_64/                     # x86_64 架构
│       └── linux-aarch64/                    # ARM64 架构
├── build.sh                                  # 多架构构建脚本
├── build-native.sh                           # Native library 构建脚本
├── build-cross-compile.sh                    # 交叉编译脚本
├── run-multiarch.sh                          # 通用运行脚本
├── Dockerfile                                # Docker 多架构构建文件
├── docker-compose.yml                        # Docker Compose 配置
├── pom.xml                                   # Maven 配置
├── README.md                                 # 项目说明
└── MULTIARCH-DEPLOYMENT.md                   # 详细部署指南
```

## 🚀 快速开始

### 1. 构建多架构 JAR 包
```bash
# 一键构建包含所有架构的 JAR 包
./build.sh
```

### 2. 运行应用程序
```bash
# 方式一：直接运行（推荐）
java -jar target/java-native-demo-multiarch-1.0.0.jar

# 方式二：使用智能运行脚本
./run-multiarch.sh

# 方式三：Docker 运行
docker build -t java-native-demo .
docker run --rm java-native-demo
```

## 📦 第三方组件（ARM64 兼容版本）

### 字节码类型组件
- **Apache Commons Codec 1.15**: Base64 编码/解码
- **Apache Commons Lang3 3.12.0**: 字符串处理工具
- **Jackson 2.15.2**: JSON 处理

### Native Library 组件
- **Snappy 1.1.10.5**: 快速压缩算法（完整 ARM64 支持）
- **Apache Commons Crypto 1.1.0**: 加密算法（ARM64 优化）
- **LZ4 1.8.0**: 高速压缩算法（ARM64 兼容）
- **JNA 5.13.0**: Java Native Access（完整 ARM64 支持）

### 自定义 Native Libraries
1. **libmathutils.so**: 数学计算库（GCD、斐波那契、质数判断）
2. **libstringutils.so**: 字符串处理库（反转、大小写、回文检测）
3. **libsysteminfo.so**: 系统信息库（架构、内存、CPU、负载）

## 🛠️ 构建要求

### 系统要求
- Linux 系统（x86_64 或 ARM64）
- OpenJDK 11 或更高版本
- GCC/G++ 编译器
- Maven 3.6+

### 安装依赖

#### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install -y openjdk-11-jdk gcc g++ maven

# 可选：安装交叉编译工具链（用于构建其他架构）
sudo apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
```

#### Amazon Linux
```bash
sudo yum update
sudo yum install -y java-11-openjdk-devel gcc gcc-c++ maven
```

## 🏗️ 构建过程详解

### 自动化构建流程
1. **环境检测**: 检查 Java、编译器等必要工具
2. **本地构建**: 构建当前系统架构的 native libraries
3. **交叉编译**: 自动尝试构建其他架构（如果工具链可用）
4. **库验证**: 验证所有架构的库文件正确性
5. **JAR 打包**: 将所有架构的库文件打包到单一 JAR 中

### 构建输出
```
✅ 构建成功完成！
📦 JAR 包: target/java-native-demo-multiarch-1.0.0.jar
🏗️  支持架构: x86_64 ARM64
📁 JAR 包大小: 7.9M
```

## 🌐 部署场景

### AWS Graviton 实例
```bash
# 直接部署，无需任何修改
java -jar java-native-demo-multiarch-1.0.0.jar
```

### 混合环境
```bash
# 同一个 JAR 包可以部署到不同架构的服务器集群
# 无需架构特定的构建或配置
```

## 🔧 高级用法

### 交叉编译
```bash
# 在 x86_64 系统上为 ARM64 构建
./build-cross-compile.sh

# 手动指定交叉编译环境
export CC=aarch64-linux-gnu-gcc
export CXX=aarch64-linux-gnu-g++
./build-native.sh
```

### 构建多架构容器镜像
介绍如何通过 `Docker buildx` 在 x86 环境下构建 `x86 和 arm64` 架构的容器镜像，并通过 `Manifest` 机制管理多架构镜像。

***但是，推荐您在 Graviton 环境下对编译构建 Arm64 架构的容器镜像。***

#### 前置条件：准备 Docker buildx 运行环境
```bash
# 1. 安装 Docker buildx（如果未安装）
sudo apt install -y docker.io
mkdir -p ~/.docker/cli-plugins
curl -L "https://github.com/docker/buildx/releases/latest/download/buildx-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)" -o ~/.docker/cli-plugins/docker-buildx
chmod +x ~/.docker/cli-plugins/docker-buildx

# 2. 启用 QEMU 多架构模拟
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# 3. 创建多架构构建器
docker buildx create --name multiarch --driver docker-container --use
docker buildx inspect --bootstrap
```

#### 在 x86 实例上构建多架构镜像
```bash
# 构建多架构镜像（本地缓存）
docker buildx build --platform linux/amd64 -t java-native-demo:amd64 --load .
docker buildx build --platform linux/arm64 -t java-native-demo:arm64 --load .

# 登录到 AWS ECR
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(cloud-init query region)
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# 创建repo
aws ecr create-repository --repository-name graviton-demos/java-native-demo --region $AWS_REGION

# 为镜像添加 ECR 仓库标签
docker tag java-native-demo:amd64 $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/graviton-demos/java-native-demo:amd64
docker tag java-native-demo:arm64 $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/graviton-demos/java-native-demo:arm64

# 推送镜像到 ECR
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/graviton-demos/java-native-demo:amd64
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/graviton-demos/java-native-demo:arm64
```
#### 通过 Manifest 管理多架构镜像

```bash
# 创建 Manifest 清单
docker manifest create \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/graviton-demos/java-native-demo:latest \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/graviton-demos/java-native-demo:amd64 \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/graviton-demos/java-native-demo:arm64

# 将 Manifest 清单推送到镜像仓库
docker manifest push \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/graviton-demos/java-native-demo:latest

# 查看镜像仓库信息
aws ecr describe-images --repository-name graviton-demos/java-native-demo
```

#### 在 Graviton 实例验证多架构镜像
```bash
# 登录到 AWS ECR
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(cloud-init query region)
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# 通过 Manifest 运行容器
docker run \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/graviton-demos/java-native-demo:latest

# 检查镜像支持的架构
docker inspect \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/graviton-demos/java-native-demo:latest | \
  grep supported.platform
```

## 🐛 故障排除

### 常见问题
1. **Native Library 加载失败**: 检查架构匹配和 JAR 包完整性
2. **交叉编译失败**: 安装对应的交叉编译工具链
3. **Java 版本不兼容**: 确保使用 OpenJDK 11 或更高版本

### 调试命令
```bash
# 检查 JAR 包内容
jar tf target/java-native-demo-multiarch-1.0.0.jar | grep native

# 验证库文件架构
file target/native/linux-*/lib*.so

# 启用详细日志
java -verbose:jni -jar target/java-native-demo-multiarch-1.0.0.jar
```

详细的故障排除指南请参考 [MULTIARCH-DEPLOYMENT.md](MULTIARCH-DEPLOYMENT.md)。

## 📝 版本历史

### v1.0.0 (Multi-Architecture)
- ✅ 实现真正的多架构支持
- ✅ 单一 JAR 包包含所有架构
- ✅ 自动架构检测和库加载
- ✅ 完整的交叉编译支持
- ✅ 优化的构建和部署流程
- ✅ 更新所有依赖到 ARM64 兼容版本

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！请确保：
1. 在多个架构上测试你的更改
2. 更新相关文档
3. 验证交叉编译功能正常

## 📄 许可证

本项目仅用于演示目的。

---

**🎉 享受真正的多架构 Java Native 应用程序！**
