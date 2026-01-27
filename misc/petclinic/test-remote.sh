#!/bin/bash

## 实例 1：容器启动 mysql
echo "=== 设置 MySQL 数据库 ==="

# 安装 Docker
sudo yum update -y
sudo yum install docker -y
sudo systemctl start docker
sudo systemctl enable docker

# 创建数据目录
mkdir -p ~/mysql-data

# 启动 MySQL
docker run -d \
  --name petclinic-mysql \
  --restart=always \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD=petclinic \
  -e MYSQL_DATABASE=petclinic \
  -e MYSQL_USER=petclinic \
  -e MYSQL_PASSWORD=petclinic \
  -v ~/mysql-data:/var/lib/mysql \
  mysql:8.0

echo "等待 MySQL 启动..."
sleep 30

# 下载并导入数据
wget -q https://raw.githubusercontent.com/spring-projects/spring-petclinic/main/src/main/resources/db/mysql/schema.sql
wget -q https://raw.githubusercontent.com/spring-projects/spring-petclinic/main/src/main/resources/db/mysql/data.sql

docker exec -i petclinic-mysql mysql -upetclinic -ppetclinic petclinic < schema.sql
docker exec -i petclinic-mysql mysql -upetclinic -ppetclinic petclinic < data.sql

echo "✅ MySQL 设置完成"
echo "私有 IP: $(hostname -i)"

###############################################################################################
## 实例 2：容器启动 petclinic 应用
echo "=== 设置 Spring Petclinic 应用 ==="
# 配置变量
EC2_APP_PRIVATE_IP="172.31.80.11"  # 替换为 EC2-B 的私有 IP

# 安装依赖
sudo yum update -y
sudo yum install docker git java-17-amazon-corretto-devel -y
sudo systemctl start docker
sudo systemctl enable docker

# 克隆项目
git clone https://github.com/spring-projects/spring-petclinic.git
cd spring-petclinic

# 创建 Dockerfile
cat > Dockerfile << 'EOF'
FROM eclipse-temurin:17-jdk-jammy AS builder
WORKDIR /app
COPY . .
RUN ./mvnw clean package -DskipTests

FROM eclipse-temurin:17-jre-jammy
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF

# 构建镜像
docker build -t petclinic:latest .

# 启动容器
docker run -d \
  --name petclinic-app \
  --restart=always \
  -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=mysql \
  -e SPRING_DATASOURCE_URL="jdbc:mysql://${EC2_APP_PRIVATE_IP}:3306/petclinic" \
  -e SPRING_DATASOURCE_USERNAME=petclinic \
  -e SPRING_DATASOURCE_PASSWORD=petclinic \
  petclinic:latest

echo "等待应用启动..."
sleep 60

# 检查状态
docker logs petclinic-app

echo "✅ 应用设置完成"
echo "访问地址: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"

###############################################################################################
## 在 Loadgen 安装 jmeter 并执行测试脚本
echo "=== 设置 Load Generator 并执行测试 ==="

# 更新系统
sudo dnf update -y

# 安装 Java（JMeter 需要）
sudo dnf install java-17-amazon-corretto -y

# 验证 Java 安装
java -version

# 下载 JMeter（最新版本 5.6.3）
cd /opt
sudo wget https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-5.6.3.tgz

# 解压
sudo tar -xzf apache-jmeter-5.6.3.tgz

# 创建符号链接
sudo ln -s /opt/apache-jmeter-5.6.3 /opt/jmeter

# 添加到 PATH
echo 'export PATH=$PATH:/opt/jmeter/bin' | sudo tee -a /etc/profile.d/jmeter.sh
source /etc/profile.d/jmeter.sh

# 验证安装
jmeter -v && echo "✅ JMeter 安装完成！"