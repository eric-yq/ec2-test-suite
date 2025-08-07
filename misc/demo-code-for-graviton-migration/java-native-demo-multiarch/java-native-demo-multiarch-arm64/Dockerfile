# Multi-stage build for Java Native Demo - Multi-Architecture Support
# 支持多架构的 Docker 构建文件

# Stage 1: Build environment
FROM openjdk:11-jdk-slim as builder

# 设置构建参数
ARG TARGETARCH
ARG BUILDARCH

# 安装构建工具
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    make \
    maven \
    file \
    libc6-dev \
    && rm -rf /var/lib/apt/lists/*

# 根据目标架构安装交叉编译工具链
RUN if [ "$BUILDARCH" = "amd64" ] && [ "$TARGETARCH" = "arm64" ]; then \
        echo "Installing ARM64 cross-compilation toolchain on AMD64..." && \
        apt-get update && \
        apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu && \
        rm -rf /var/lib/apt/lists/*; \
    elif [ "$BUILDARCH" = "arm64" ] && [ "$TARGETARCH" = "amd64" ]; then \
        echo "Installing AMD64 cross-compilation toolchain on ARM64..." && \
        apt-get update && \
        apt-get install -y gcc-x86-64-linux-gnu g++-x86-64-linux-gnu && \
        rm -rf /var/lib/apt/lists/*; \
    else \
        echo "Native compilation: $BUILDARCH -> $TARGETARCH"; \
    fi

# 设置工作目录
WORKDIR /app

# 复制源代码
COPY . .

# 设置脚本权限并构建应用程序
RUN chmod +x build-native.sh build.sh build-cross-compile.sh run-multiarch.sh && \
    echo "Building for BUILDARCH=$BUILDARCH, TARGETARCH=$TARGETARCH" && \
    ./build.sh

# 验证构建结果
RUN echo "Verifying build results..." && \
    ls -la target/ && \
    ls -la target/native/ && \
    jar tf target/java-native-demo-multiarch-1.0.0.jar | grep "^native/" | head -10

# Stage 2: Runtime environment
FROM openjdk:11-jre-slim

# 设置运行时参数
ARG TARGETARCH

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

# 从构建阶段复制应用程序
COPY --from=builder /app/target/java-native-demo-multiarch-1.0.0.jar app.jar
COPY --from=builder /app/run-multiarch.sh run-multiarch.sh

# 可选：复制外部 native libraries（用于调试）
COPY --from=builder /app/target/native/ native/

# 创建启动脚本
RUN echo '#!/bin/bash' > /app/start.sh && \
    echo 'echo "Container Architecture: $(uname -m)"' >> /app/start.sh && \
    echo 'echo "Target Architecture: '$TARGETARCH'"' >> /app/start.sh && \
    echo 'echo "JAR file info:"' >> /app/start.sh && \
    echo 'ls -lh app.jar' >> /app/start.sh && \
    echo 'echo "Native libraries in JAR:"' >> /app/start.sh && \
    echo 'jar tf app.jar | grep "^native/" | head -5' >> /app/start.sh && \
    echo 'echo "Starting application..."' >> /app/start.sh && \
    echo 'exec java $JAVA_OPTS -jar app.jar' >> /app/start.sh && \
    chmod +x /app/start.sh

# 设置文件权限
RUN chown -R appuser:appuser /app

# 切换到应用用户
USER appuser

# 设置环境变量
ENV JAVA_OPTS="-Xmx512m -Xms256m"

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD java -version || exit 1

# 暴露端口（如果需要）
# EXPOSE 8080

# 启动应用程序
CMD ["/app/start.sh"]

# 添加标签
LABEL maintainer="demo@example.com"
LABEL version="1.0.0"
LABEL description="Java Native Demo Multi-Architecture Application"
LABEL architecture="multi-arch"
LABEL supported.platforms="linux/amd64,linux/arm64"
