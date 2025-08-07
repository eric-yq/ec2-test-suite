# Java Native Demo Multi-Architecture (x86_64 专用版本)

这是一个演示 Java 应用程序与 native libraries 集成的项目，包含第三方组件的使用和自定义 native library 的调用。本项目使用专门针对 x86_64 架构优化的旧版本依赖。

## 项目结构

```
java-native-demo-multiarch/
├── src/
│   └── main/
│       ├── java/com/example/demo/
│       │   ├── NativeDemoApplication.java    # 主应用程序
│       │   ├── MathUtils.java                # 数学工具类
│       │   ├── StringUtils.java              # 字符串工具类
│       │   ├── SystemInfo.java               # 系统信息类
│       │   └── ThirdPartyDemo.java           # 第三方组件演示
│       ├── cpp/
│       │   ├── mathutils.cpp                 # 数学工具 native 实现
│       │   ├── stringutils.cpp               # 字符串工具 native 实现
│       │   └── systeminfo.cpp                # 系统信息 native 实现
│       └── resources/
├── target/
│   └── native/linux-x86_64/                 # 编译后的 .so 文件
├── pom.xml                                   # Maven 配置
├── build-native.sh                          # Native library 构建脚本
├── build.sh                                 # 完整构建脚本
├── Dockerfile                               # Docker 构建文件
├── docker-compose.yml                       # Docker Compose 配置
└── README.md                                # 项目说明
```

## 功能特性

### 第三方组件集成

#### 字节码类型组件（x86_64 专用旧版本）
- **Apache Commons Codec 1.9**: Base64 编码/解码（2014年发布，x86_64 专用优化）
- **Apache Commons Lang3 3.4**: 字符串处理工具（2015年发布，x86_64 架构专用）
- **Jackson 2.8.11**: JSON 处理（2017年发布，x86_64 专用版本）

#### Native Library 组件（x86_64 专用旧版本）
- **Snappy 1.1.2.6**: 快速压缩算法（2016年发布，仅支持 x86_64）
- **Apache Commons Crypto 1.0.0**: 加密算法，使用 OpenSSL（2016年发布，x86_64 专用）
- **LZ4 1.4.1**: 高速压缩算法（2016年发布，x86_64 架构专用）
- **JNA 4.5.2**: Java Native Access（2018年发布，主要支持 x86_64）

### 自定义 Native Libraries

1. **libmathutils.so**: 数学计算库
   - 最大公约数计算
   - 斐波那契数列
   - 质数判断

2. **libstringutils.so**: 字符串处理库
   - 字符串反转
   - 大小写转换
   - 字符计数
   - 回文检测

3. **libsysteminfo.so**: 系统信息库
   - 系统架构信息
   - 内核版本
   - CPU 核心数
   - 内存信息
   - 系统负载

## 构建要求

### 系统要求
- Linux x86_64 系统
- OpenJDK 11 或更高版本
- GCC/G++ 编译器
- Maven 3.6+

### 安装依赖（Ubuntu/Debian）
```bash
sudo apt-get update
sudo apt-get install -y openjdk-11-jdk gcc g++ maven
```

## 构建和运行

### 方式一：直接构建
```bash
# 克隆或下载项目
cd java-native-demo-multiarch

# 执行完整构建
./build.sh

# 运行应用程序
java -Djava.library.path=target/native/linux-x86_64 -jar target/java-native-demo-multiarch-1.0.0.jar
```

### 方式二：分步构建
```bash
# 1. 构建 native libraries
./build-native.sh

# 2. 构建 Java 应用程序
mvn clean compile package

# 3. 运行
java -Djava.library.path=target/native/linux-x86_64 -jar target/java-native-demo-multiarch-1.0.0.jar
```

### 方式三：使用 Docker
```bash
# 构建 Docker 镜像
docker build -t java-native-demo .

# 运行容器
docker run --rm java-native-demo

# 或使用 Docker Compose
docker-compose up --build
```

## 输出示例

应用程序运行时会展示以下内容：

1. **字节码组件演示（x86_64 专用旧版本）**：
   - Commons Codec 1.9: Base64 编码/解码
   - Commons Lang3 3.4: 字符串处理（trim、capitalize、reverse）
   - Jackson 2.8.11: JSON 操作

2. **Native 组件演示（x86_64 专用旧版本）**：
   - Snappy 1.1.2.6: 压缩操作（约84%压缩率）
   - LZ4 1.4.1: 高速压缩（约93%压缩率）
   - Commons Crypto 1.0.0: AES 加密操作

3. **自定义 Native Libraries 演示**：
   - 数学计算（GCD、斐波那契、质数）
   - 字符串操作（反转、大小写、回文）
   - 系统信息（架构、内存、CPU）

## 架构说明

当前版本专门针对 **x86_64** 架构进行了优化：

- Native libraries 编译为 x86_64 格式
- Docker 镜像基于 x86_64 基础镜像
- 所有依赖项都是 x86_64 兼容的

## 故障排除

### Native Library 加载失败
```bash
# 检查 .so 文件是否存在
ls -la target/native/linux-x86_64/

# 检查文件格式
file target/native/linux-x86_64/libmathutils.so

# 检查依赖
ldd target/native/linux-x86_64/libmathutils.so
```

### Java 环境问题
```bash
# 检查 Java 版本
java -version
javac -version

# 检查 JAVA_HOME
echo $JAVA_HOME
```

### 编译错误
```bash
# 检查编译器
gcc --version
g++ --version

# 手动编译单个库进行调试
gcc -fPIC -O2 -Wall -I$JAVA_HOME/include -I$JAVA_HOME/include/linux -shared \
    -o libtest.so src/main/cpp/mathutils.cpp
```

## 许可证

本项目仅用于演示目的。

## 贡献

欢迎提交 Issue 和 Pull Request。
