#!/bin/bash

## 安装 Java
yum update -y

## Corretto 25
yum install -y java-25-amazon-corretto java-25-amazon-corretto-devel python3-pip git
pip3 install dool
JDK_VERSION='corretto25'
java -version

## 启动 spring-petclinic 应用
cd /root/
git clone https://github.com/spring-projects/spring-petclinic.git
cd spring-petclinic
./mvnw package
cp target/*.jar /usr/local/bin/spring-petclinic.jar
#nohup java -jar target/*.jar &

#创建 systemd 服务文件:
cat << EOF > /etc/systemd/system/petclinic.service
[Unit]
Description=Spring PetClinic Application
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/java -jar /usr/local/bin/spring-petclinic.jar
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 启用并启动服务:
systemctl daemon-reload
systemctl enable petclinic.service
systemctl start petclinic.service
# 检查状态:
systemctl status petclinic.service

