# Java Native Demo - Multi-Architecture Support

这个项目演示了如何构建支持多架构（x86_64 和 ARM64）的 Java 应用程序，包含 native 库依赖。

## 项目特性

### 多架构支持
- **JAR 包构建**: 在任何架构上构建的 JAR 包都可以在 x86_64 和 ARM64 架构上运行
- **容器镜像构建**: 支持构建 x86_64 和 ARM64 架构的容器镜像
- **自动架构检测**: 运行时自动检测架构并加载对应的 native 库

### 依赖类型演示

本项目演示了三种不同类型的 native 依赖处理：

1. **第三方字节码依赖**: 纯 Java 字节码，但内部可能调用 JNI
   - snappy-java 1.1.10.5 (内嵌多架构 native 库)
   - commons-crypto 1.2.0 (内嵌多架构 native 库)
   - JNA 5.14.0 (提供 native 调用框架)

2. **第三方 Native 库依赖**: JAR 包中直接包含 .so/.dll/.dylib 文件
   - RocksDB 8.11.4 (包含 librocksdbjni-linux-x86_64.so, librocksdbjni-linux-aarch64.so 等)

3. **自定义 Native 库**: 项目自己编译的 C/C++ 库，通过 JNA 调用
   - libmath_ops.so (数学运算)
   - libstring_ops.so (字符串操作)
   - libsystem_ops.so (系统信息)

## 构建和运行

### 前置要求
- Java 11+
- GCC/G++ 编译器
- Make
- Docker (可选，用于容器构建)

### 安装交叉编译工具

在 x86_64 系统上安装 ARM64 交叉编译工具：
```bash
sudo apt-get update
sudo apt-get install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
```

在 ARM64 系统上安装 x86_64 交叉编译工具：
```bash
sudo apt-get update
sudo apt-get install gcc-x86-64-linux-gnu g++-x86-64-linux-gnu
```

### 构建 JAR 包

```bash
# 方式1: 完整构建（包含交叉编译工具检查）
./build.sh

# 方式2: 跳过交叉编译工具检查
./build.sh --skip-cross-check

# 方式3: 快速增量构建（推荐）
./build-fast.sh

# 方式4: 快速完全清理构建
./build-fast.sh --clean
```

**构建方式说明**:
- `build.sh`: 完整构建流程，包含工具检查和用户交互
- `build-fast.sh`: 优化的构建流程，支持增量编译，避免重复编译 native 库
- `build-fast.sh --clean`: 强制完全清理后重新构建

构建完成后，生成的 JAR 包包含以下 native 库：
- `libmath_ops_x86_64.so` 和 `libmath_ops_aarch64.so`
- `libstring_ops_x86_64.so` 和 `libstring_ops_aarch64.so`
- `libsystem_ops_x86_64.so` 和 `libsystem_ops_aarch64.so`

### 运行应用

```bash
# 使用构建脚本运行
./run.sh

# 或直接运行 JAR
java -jar build/libs/java-native-demo-multiarch-gradle-arm64-1.0.0-all.jar
```

### 构建容器镜像

```bash
# 构建多架构容器镜像
./docker-build.sh
```

支持的构建方式：
1. **Docker Buildx** (推荐): 构建 linux/amd64 和 linux/arm64 镜像
2. **传统方式**: 构建当前架构的镜像

### 验证多架构支持

```bash
# 运行验证脚本
./verify-multiarch.sh
```

## 架构兼容性

| 构建环境 | 生成的 JAR | 运行环境支持 |
|---------|-----------|-------------|
| x86_64  | 多架构 JAR | x86_64 + ARM64 |
| ARM64   | 多架构 JAR | x86_64 + ARM64 |

| 构建环境 | 容器镜像 | 支持的架构 |
|---------|---------|-----------|
| x86_64  | 多架构镜像 | linux/amd64 + linux/arm64 |
| ARM64   | 多架构镜像 | linux/amd64 + linux/arm64 |

## 技术实现

### Native 库加载策略
1. **架构检测**: 通过 `System.getProperty("os.arch")` 检测当前架构
2. **库选择**: 根据架构选择对应的 native 库文件
3. **回退机制**: 如果找不到架构特定的库，尝试加载通用库

### 构建流程
1. **Native 编译**: 使用 Makefile 编译本地架构和交叉编译目标架构的库
2. **资源打包**: 将所有架构的 native 库打包到 JAR 的 resources 目录
3. **运行时加载**: 应用启动时根据当前架构选择并加载对应的库

### Docker 多架构构建
- 使用 Docker Buildx 支持多平台构建
- 在构建阶段安装交叉编译工具
- 生成包含多架构 native 库的镜像

## 文件结构

```
├── src/main/java/com/example/demo/
│   ├── NativeDemoApplication.java          # 主应用类
│   ├── CustomNativeLibraryDemo.java        # 自定义 native 库演示（支持多架构）
│   └── ThirdPartyLibraryDemo.java          # 第三方库演示
├── native/
│   ├── Makefile                            # 多架构构建配置
│   └── src/                                # C/C++ 源代码
├── build.gradle                            # Gradle 构建配置（多架构依赖）
├── Dockerfile                              # 多架构容器构建
├── build.sh                                # 多架构 JAR 构建脚本
├── docker-build.sh                         # 多架构容器构建脚本
├── verify-multiarch.sh                     # 多架构验证脚本
└── README.md                               # 本文档
```

## 故障排除

### 常见问题

1. **交叉编译工具未安装**
   ```
   Warning: Cross compiler aarch64-linux-gnu-gcc not found
   ```
   解决方案: 运行 `make install-cross-tools` 或手动安装交叉编译工具

2. **Native 库加载失败**
   ```
   java.lang.UnsatisfiedLinkError: Unable to load library
   ```
   解决方案: 检查 JAR 中是否包含对应架构的 native 库

3. **Docker Buildx 不可用**
   ```
   ERROR: Docker Buildx is required for multi-architecture builds
   ```
   解决方案: 升级 Docker 或安装 Buildx 插件

### 调试信息

启用详细日志：
```bash
java -Dorg.slf4j.simpleLogger.defaultLogLevel=DEBUG -jar build/libs/java-native-demo-multiarch-gradle-arm64-1.0.0-all.jar
```

## 性能对比

该项目可以用来测试和对比不同架构下的性能表现，特别是：
- Native 库调用性能
- 第三方库在不同架构下的表现
- 容器运行时性能差异

## 许可证

MIT License
