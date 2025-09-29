#!/bin/bash

echo "=== 构建Spring Boot应用 ==="
mvn clean package -DskipTests

echo "=== 启动应用 ==="
java -jar target/springboot-demo-1.0.0.jar
