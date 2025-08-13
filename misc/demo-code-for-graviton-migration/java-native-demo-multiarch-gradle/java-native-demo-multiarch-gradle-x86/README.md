# Java Native Demo (x86_64 Only)

这是一个演示 Java 调用 native libraries 的项目，专门针对 x86_64 架构设计。

## 项目特性

- **第三方组件演示**：
  - Snappy 压缩库（字节码 + native .so）
  - Apache Commons Crypto 加密库（字节码 + native .so）
  - RocksDB 数据库（.so 文件组件）

- **自定义 Native Libraries**：
  - `libmath_ops.so` - 数学运算库
  - `libstring_ops.so` - 字符串操作库
  - `libsystem_ops.so` - 系统信息库

- **架构限制**：
  - 仅支持 x86_64 架构
  - 使用旧版本依赖（不支持 aarch64/arm64）

## 构建要求

- Java 11+
- Gradle 6.0+
- GCC/G++ 编译器
- x86_64 架构系统
- OpenSSL 开发库（推荐 3.0+）

## OpenSSL 兼容性

项目使用 Apache Commons Crypto 进行加密操作，支持以下模式：

- **OpenSSL Native**：优先使用 OpenSSL native 实现（性能更好）
- **JCE 降级**：当 OpenSSL native 不可用时，自动降级到 Java JCE 实现

### OpenSSL 安装

在 Ubuntu/Debian 系统上：
```bash
sudo apt-get update
sudo apt-get install libssl-dev openssl
```

在 CentOS/RHEL 系统上：
```bash
sudo yum install openssl-devel openssl
```

## 快速开始

### 1. 构建项目

```bash
# 编译 native libraries
cd native
make clean && make all

# 构建 Java 应用
./gradlew clean build fatJar
```

### 2. 运行应用

```bash
# 运行主程序
java -jar build/libs/java-native-demo-multiarch-gradle-x86-1.0.0-all.jar

# 或使用 Gradle
./gradlew run
```

### 3. 运行测试

```bash
./gradlew test
```

## 运行示例

成功运行时，应用会依次演示所有 native library 功能：

```
=== Snappy Compression Demo ===
Original text length: 188 bytes
Compressed length: 166 bytes
Compression ratio: 11.70%
Decompression successful: true
Snappy native library is working correctly

=== Apache Commons Crypto Demo ===
OpenSSL native implementation failed, falling back to JCE
Using JCE implementation
Original text: Hello, this is a secret message for encryption!
Encrypted length: 47 bytes
Decrypted text: Hello, this is a secret message for encryption!
Encryption/Decryption successful: true
Commons Crypto native library is working correctly

=== RocksDB Demo ===
RocksDB opened successfully at: /tmp/rocksdb-demo-xxxxx
Data written to RocksDB
Retrieved: user:1001 = John Doe
Retrieved: user:1002 = Jane Smith
RocksDB native library is working correctly

=== Math Library Demo ===
Math operations:
  15 + 25 = 40
  15 * 25 = 375
  sqrt(144.0) = 12.0
Math library is working correctly

=== String Library Demo ===
String operations:
  Original: 'Hello Native World'
  Length: 18
  Reversed: 'dlroW evitaN olleH'
  Uppercase: 'HELLO NATIVE WORLD'
String library is working correctly

=== System Library Demo ===
System information:
  Current timestamp: 1755052470390
  Process ID: 14591
  System info: System: Linux, Node: hostname, Release: 6.x.x, Machine: x86_64
System library is working correctly

All demonstrations completed successfully
```

## Docker 支持

### 构建 Docker 镜像

```bash
docker build -t java-native-demo:x86_64 .
```

### 运行 Docker 容器

```bash
docker run --rm java-native-demo:x86_64
```

## 项目结构

```
java-native-demo-multiarch-gradle-x86/
├── src/
│   ├── main/
│   │   ├── java/com/example/demo/
│   │   │   ├── NativeDemoApplication.java
│   │   │   ├── ThirdPartyLibraryDemo.java
│   │   │   └── CustomNativeLibraryDemo.java
│   │   └── resources/
│   │       ├── logback.xml
│   │       └── native/          # Native libraries 存放位置
│   └── test/
│       └── java/com/example/demo/
│           └── NativeDemoTest.java
├── native/
│   ├── src/
│   │   ├── math_ops.c
│   │   ├── string_ops.c
│   │   └── system_ops.cpp
│   ├── build/                   # 编译输出目录
│   └── Makefile
├── build.gradle
├── Dockerfile
└── README.md
```

## 依赖说明

### 第三方组件（字节码）
- `snappy-java:1.1.7.3` - 旧版本，不支持 aarch64
- `commons-crypto:1.1.0` - 兼容 OpenSSL 3.0+ 的版本
- `jna:5.5.0` - 用于 native 调用

### 第三方组件（.so 文件）
- `rocksdbjni:6.15.5` - 旧版本，包含 x86_64 的 .so 文件

## 注意事项

1. **架构限制**：此项目仅支持 x86_64 架构
2. **依赖版本**：故意使用不支持 aarch64 的旧版本
3. **Native Libraries**：需要先编译 C/C++ 代码
4. **内存管理**：注意 native 代码中的内存分配和释放

## 故障排除

### 常见问题

1. **UnsatisfiedLinkError**：
   - 确保 native libraries 已正确编译
   - 检查架构是否为 x86_64

2. **编译错误**：
   - 安装必要的构建工具：`build-essential gcc g++ make`
   - 确保在 x86_64 系统上构建

3. **Commons Crypto OpenSSL 错误**：
   - 如果看到 `EVP_CIPHER_CTX_cleanup` 错误，说明 OpenSSL 版本不兼容
   - 应用会自动降级到 JCE 实现，功能不受影响
   - 检查日志中的 "Using JCE implementation" 消息

4. **自定义 Native 库加载错误**：
   - 如果看到 `Unable to load library 'math_ops'` 等错误，通常是 JNA 库路径问题
   - 确保所有 .so 文件都被正确提取到同一个临时目录
   - 检查日志中的 "Extracted native library" 和 "JNA library path set to" 消息
   - 验证提取的库文件具有正确的执行权限

5. **运行时错误**：
   - 检查日志文件：`logs/native-demo.log`
   - 确保所有依赖库已正确加载

### OpenSSL 版本兼容性

- **OpenSSL 3.0+**：完全支持，推荐使用
- **OpenSSL 1.1.x**：支持，但可能有性能差异
- **OpenSSL 1.0.x**：不推荐，可能出现兼容性问题

如果遇到 OpenSSL native 加载失败，应用会自动使用 Java JCE 实现，确保加密功能正常工作。

## 许可证

MIT License
