# Multi-stage build for Java Native Demo (x86_64 only)

# Stage 1: Build environment
FROM openjdk:11-jdk-slim as builder

# 安装构建工具
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    g++ \
    make \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 复制项目文件
COPY . .

# 构建 native libraries
RUN cd native && make clean && make all

# 构建 Java 应用
RUN ./gradlew clean build fatJar --no-daemon

# Stage 2: Runtime environment (x86_64 only)
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

# 从构建阶段复制 JAR 文件
COPY --from=builder /app/build/libs/*-all.jar app.jar

# 创建日志目录
RUN mkdir -p logs && chown -R appuser:appuser /app

# 切换到应用用户
USER appuser

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD java -cp app.jar com.example.demo.NativeDemoApplication --health-check || exit 1

# 暴露端口（如果需要）
EXPOSE 8080

# 设置 JVM 参数
ENV JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseG1GC -XX:+UseContainerSupport"

# 启动应用
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]

# 元数据标签
LABEL maintainer="demo@example.com"
LABEL version="1.0.0"
LABEL description="Java Native Demo Application (x86_64 only)"
LABEL architecture="x86_64"
