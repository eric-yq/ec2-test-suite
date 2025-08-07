# Multi-stage build for Java Native Demo
# Stage 1: Build environment
FROM openjdk:11-jdk-slim as builder

# 安装构建工具
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    make \
    maven \
    file \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 复制源代码
COPY . .

# 构建应用程序
RUN chmod +x build-native.sh build.sh && \
    ./build.sh

# Stage 2: Runtime environment
FROM openjdk:11-jre-slim

# 安装运行时依赖
RUN apt-get update && apt-get install -y \
    libc6 \
    libgcc-s1 \
    libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

# 创建应用用户
RUN groupadd -r appuser && useradd -r -g appuser appuser

# 设置工作目录
WORKDIR /app

# 从构建阶段复制应用程序和 native libraries
COPY --from=builder /app/target/java-native-demo-multiarch-1.0.0.jar app.jar
COPY --from=builder /app/target/native/linux-x86_64/*.so /app/native/

# 设置文件权限
RUN chown -R appuser:appuser /app

# 切换到应用用户
USER appuser

# 设置环境变量
ENV JAVA_OPTS="-Xmx512m -Xms256m"
ENV NATIVE_LIB_PATH="/app/native"

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD java -version || exit 1

# 暴露端口（如果需要）
# EXPOSE 8080

# 启动应用程序
CMD ["sh", "-c", "java $JAVA_OPTS -Djava.library.path=$NATIVE_LIB_PATH -jar app.jar"]

# 添加标签
LABEL maintainer="demo@example.com"
LABEL version="1.0.0"
LABEL description="Java Native Demo Multi-Architecture Application"
LABEL architecture="x86_64"
