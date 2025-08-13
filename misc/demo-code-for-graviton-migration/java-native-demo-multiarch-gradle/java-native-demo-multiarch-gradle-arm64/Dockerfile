# Multi-stage build for Java Native Demo (Multi-architecture support)

# Stage 1: Build environment
FROM --platform=$BUILDPLATFORM openjdk:11-jdk-slim as builder

# 声明构建参数
ARG BUILDPLATFORM
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH

# 显示构建信息
RUN echo "Building on: $BUILDPLATFORM, targeting: $TARGETPLATFORM"

# 安装构建工具和交叉编译工具
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    g++ \
    make \
    && \
    # 根据目标架构安装交叉编译工具 \
    if [ "$TARGETARCH" = "arm64" ] && [ "$(uname -m)" = "x86_64" ]; then \
        apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu; \
    elif [ "$TARGETARCH" = "amd64" ] && [ "$(uname -m)" = "aarch64" ]; then \
        apt-get install -y gcc-x86-64-linux-gnu g++-x86-64-linux-gnu; \
    fi && \
    rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 复制项目文件
COPY . .

# 构建 native libraries（多架构支持）
RUN cd native && \
    make clean && \
    make multiarch && \
    ls -la build/

# 构建 Java 应用
RUN ./gradlew clean build fatJar --no-daemon

# 显示构建结果
RUN echo "Build completed for $TARGETPLATFORM" && \
    ls -la build/libs/ && \
    ls -la src/main/resources/native/

# Stage 2: Runtime environment (Multi-architecture)
FROM openjdk:11-jre-slim

# 声明运行时参数
ARG TARGETPLATFORM
ARG TARGETARCH

# 根据架构安装运行时依赖
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

# 设置 JVM 参数（根据架构优化）
ENV JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseG1GC -XX:+UseContainerSupport"

# 启动应用
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]

# 元数据标签
LABEL maintainer="demo@example.com"
LABEL version="1.0.0"
LABEL description="Java Native Demo Application (Multi-architecture)"
LABEL architecture="multi"
LABEL platforms="linux/amd64,linux/arm64"
