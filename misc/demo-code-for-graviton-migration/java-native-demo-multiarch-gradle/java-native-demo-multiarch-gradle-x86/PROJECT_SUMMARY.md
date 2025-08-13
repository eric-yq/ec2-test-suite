# Java Native Demo Project Summary

## 项目概述

这是一个完整的 Java 工程，专门设计用于演示 Java 应用程序与 native libraries 的集成，仅支持 x86_64 架构。

## 项目特性

### 1. 第三方组件演示
- **Snappy 压缩库** (`snappy-java:1.1.7.3`)
  - 类型：字节码 + native .so
  - 状态：✅ 工作正常
  - 功能：数据压缩和解压缩

- **Apache Commons Crypto** (`commons-crypto:1.0.0`)
  - 类型：字节码 + native .so
  - 状态：⚠️ 部分功能受限（演示旧版本兼容性问题）
  - 功能：加密和解密

- **RocksDB** (`rocksdbjni:6.15.5`)
  - 类型：.so 文件组件
  - 状态：✅ 预期工作正常
  - 功能：嵌入式数据库

### 2. 自定义 Native Libraries
- **libmath_ops.so** - 数学运算库
  - 加法、乘法、平方根运算
  - C 语言实现

- **libstring_ops.so** - 字符串操作库
  - 字符串长度、反转、大写转换
  - C 语言实现

- **libsystem_ops.so** - 系统信息库
  - 时间戳、进程ID、系统信息获取
  - C++ 语言实现

### 3. 架构限制
- **仅支持 x86_64 架构**
- **故意使用不支持 aarch64/arm64 的旧版本依赖**
- **构建时进行架构检查**

## 技术栈

- **Java**: OpenJDK 11
- **构建工具**: Gradle 6.9.4
- **Native 编译**: GCC/G++
- **容器化**: Docker
- **日志**: Logback + SLF4J
- **测试**: JUnit 4
- **Native 调用**: JNA (Java Native Access)

## 项目结构

```
java-native-demo-multiarch-gradle-x86/
├── src/
│   ├── main/
│   │   ├── java/com/example/demo/
│   │   │   ├── NativeDemoApplication.java      # 主应用程序
│   │   │   ├── ThirdPartyLibraryDemo.java      # 第三方库演示
│   │   │   └── CustomNativeLibraryDemo.java    # 自定义库演示
│   │   └── resources/
│   │       ├── logback.xml                     # 日志配置
│   │       └── native/                         # Native libraries 存放
│   └── test/
│       └── java/com/example/demo/
│           └── NativeDemoTest.java             # 测试类
├── native/
│   ├── src/
│   │   ├── math_ops.c                          # 数学运算库源码
│   │   ├── string_ops.c                        # 字符串操作库源码
│   │   └── system_ops.cpp                      # 系统信息库源码
│   ├── build/                                  # 编译输出
│   └── Makefile                                # 构建配置
├── build.gradle                                # Gradle 构建配置
├── Dockerfile                                  # Docker 镜像配置
├── build.sh                                    # 构建脚本
├── run.sh                                      # 运行脚本
├── verify.sh                                   # 验证脚本
├── docker-build.sh                             # Docker 构建脚本
└── README.md                                   # 项目文档
```

## 构建和运行

### 1. 环境要求
- x86_64 架构系统
- Java 11+
- GCC/G++ 编译器
- Make 工具

### 2. 快速开始
```bash
# 验证环境
./verify.sh

# 构建项目
./build.sh

# 运行应用
./run.sh

# 构建 Docker 镜像
./docker-build.sh
```

### 3. 手动构建
```bash
# 编译 native libraries
cd native && make clean && make all

# 构建 Java 应用
./gradlew clean build fatJar -x test

# 运行应用
java -jar build/libs/java-native-demo-multiarch-gradle-x86-1.0.0-all.jar
```

## 验证结果

✅ **架构检查**: 确认运行在 x86_64 系统上
✅ **工具检查**: GCC, G++, Make, Java 11 全部可用
✅ **项目结构**: 所有必需文件存在
✅ **Native 编译**: 3个 .so 文件成功编译
✅ **Java 编译**: 源码编译成功
✅ **JAR 构建**: Fat JAR (40MB+) 包含所有依赖
✅ **应用启动**: 成功启动并开始执行演示

## 演示效果

1. **Snappy 压缩**: 成功压缩和解压缩文本数据
2. **Commons Crypto**: 展示旧版本兼容性问题（预期行为）
3. **自定义 Native**: 通过 JNA 调用自定义 C/C++ 库
4. **架构限制**: 仅在 x86_64 上运行，其他架构会报错

## Docker 支持

- **多阶段构建**: 分离构建和运行环境
- **架构检查**: 确保仅在 x86_64 容器中运行
- **安全实践**: 非 root 用户运行
- **健康检查**: 内置应用健康监控

## 注意事项

1. **架构限制**: 此项目故意设计为仅支持 x86_64
2. **依赖版本**: 使用不支持 aarch64 的旧版本依赖
3. **Native Libraries**: 需要先编译 C/C++ 代码
4. **内存管理**: 注意 native 代码中的内存分配和释放
5. **兼容性**: 某些第三方库可能在不同环境中表现不同

## 扩展可能

1. **多架构支持**: 可以扩展为支持多架构的版本
2. **更多 Native 库**: 添加更多自定义 native 功能
3. **性能测试**: 添加 native 调用的性能基准测试
4. **CI/CD**: 集成持续集成和部署流程

## 许可证

MIT License - 详见项目根目录 LICENSE 文件
