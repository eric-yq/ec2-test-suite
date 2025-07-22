# Java Native Library Demo

这是一个演示Java调用native库的完整项目，包含了多种native库的使用示例以及自定义C++库的集成。

## 项目特性

- **第三方Native库集成**：
  - Snappy：Google开发的快速压缩库
  - Apache Commons Crypto：高性能加密库
  - LevelDB JNI：高性能键值存储数据库

- **自定义Native库**：
  - C++实现的数学运算函数
  - 字符串处理函数
  - JNI接口封装

- **Docker支持**：
  - 多阶段构建优化镜像大小
  - x86架构专用配置
  - 生产环境就绪的配置

## 项目结构

```
java-native-demo/
├── src/main/java/com/example/
│   ├── NativeDemoApplication.java    # 主应用程序
│   ├── NativeLibraryDemo.java        # Native库演示
│   └── MathUtils.java                # 自定义Native库接口
├── native/
│   ├── mathutils.cpp                 # C++源代码
│   └── Makefile                      # 编译配置
├── pom.xml                           # Maven配置
├── Dockerfile                        # Docker构建文件
├── docker-compose.yml                # Docker Compose配置
├── build.sh                          # 构建脚本
└── README.md                         # 项目说明
```

## 构建和运行

### 本地构建

1. **安装依赖**：
   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install openjdk-11-jdk maven build-essential g++
   
   # CentOS/RHEL
   sudo yum install java-11-openjdk-devel maven gcc-c++
   ```

2. **构建项目**：
   ```bash
   ./build.sh
   ```

3. **运行应用**：
   ```bash
   java -jar target/java-native-demo-1.0.0.jar
   ```

### Docker构建

1. **构建镜像**：
   ```bash
   docker build -t java-native-demo .
   ```

2. **运行容器**：
   ```bash
   docker run --rm java-native-demo
   ```

3. **使用Docker Compose**：
   ```bash
   docker-compose up --build
   ```

## 功能演示

应用程序将依次演示以下功能：

1. **Snappy压缩**：
   - 文本压缩和解压缩
   - 压缩率计算

2. **Apache Commons Crypto**：
   - AES加密和解密
   - 性能优化的加密操作

3. **LevelDB数据库**：
   - 键值对存储
   - 数据读取和删除操作

4. **自定义Native库**：
   - 数学运算（加法、平方根、阶乘）
   - 字符串处理

## 技术细节

### Native库加载机制

项目使用了智能的native库加载机制：
- 自动从JAR包中提取native库
- 创建临时文件进行加载
- 支持打包后的独立运行

### 内存管理

- JNI调用中正确的内存管理
- 字符串资源的及时释放
- 异常安全的代码设计

### 安全考虑

- Docker容器使用非root用户运行
- 资源限制配置
- 健康检查机制

## 性能优化

- Maven Shade插件创建fat JAR
- 多阶段Docker构建减小镜像大小
- JVM参数优化配置

## 故障排除

### 常见问题

1. **Native库加载失败**：
   - 检查Java版本兼容性
   - 确认系统架构为x86_64
   - 验证编译环境配置

2. **编译错误**：
   - 安装完整的构建工具链
   - 检查JAVA_HOME环境变量
   - 确认Maven配置正确

3. **Docker构建失败**：
   - 检查Docker版本
   - 确认网络连接正常
   - 查看构建日志详细信息

## 扩展开发

要添加新的native函数：

1. 在`mathutils.cpp`中添加C++实现
2. 在`MathUtils.java`中添加native方法声明
3. 重新编译native库
4. 在演示类中添加调用示例

## 许可证

本项目仅用于学习和演示目的。

## 联系信息

如有问题或建议，请创建Issue或提交Pull Request。
