# 多阶段构建 Dockerfile
# 阶段1: 构建环境
FROM openjdk:11-jdk-slim as builder

# 安装构建工具
RUN apt-get update && apt-get install -y \
    build-essential \
    g++ \
    make \
    maven \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 复制项目文件
COPY pom.xml .
COPY src/ src/
COPY native/ native/

# 构建native库
WORKDIR /app/native
RUN make clean && make

# 安装native库到resources目录
RUN make install

# 构建Java项目
WORKDIR /app
RUN mvn clean package -DskipTests

# 阶段2: 运行环境
FROM openjdk:11-jre-slim

# 安装运行时依赖
RUN apt-get update && apt-get install -y \
    libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

# 创建应用用户
RUN groupadd -r appuser && useradd -r -g appuser appuser

# 设置工作目录
WORKDIR /app

# 从构建阶段复制JAR文件
COPY --from=builder /app/target/java-native-demo-1.0.0.jar app.jar

# 更改文件所有者
RUN chown -R appuser:appuser /app

# 切换到应用用户
USER appuser

# 设置JVM参数
ENV JAVA_OPTS="-Xmx512m -Xms256m"

# 暴露端口（如果需要）
# EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD java -version || exit 1

# 启动应用
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]

# 添加标签
LABEL maintainer="<your-email>" \
      version="1.0.0" \
      description="Java Native Library Demo Application" \
      architecture="x86_64"
