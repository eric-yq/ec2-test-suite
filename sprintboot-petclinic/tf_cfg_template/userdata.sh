#!/bin/bash

set -e

# 实例启动成功之后的首次启动 OS， /root/userdata.sh 不存在，创建该 userdata.sh 文件并设置开启自动执行该脚本。
if [ ! -f "/root/userdata.sh" ]; then
    echo "首次启动 OS, 未找到 /root/userdata.sh，准备创建..."
    # 复制文件
    cp /var/lib/cloud/instance/scripts/part-001 /root/userdata.sh
    chmod +x /root/userdata.sh
    # 创建 systemd 服务单元
    cat > /etc/systemd/system/userdata.service << EOF
[Unit]
Description=Execute userdata script at boot
After=network.target

[Service]
Type=oneshot
User=root
ExecStart=/root/userdata.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    # 启用服务
    systemctl daemon-reload
    systemctl enable userdata.service
    
    echo "已创建并启用 systemd 服务 userdata.service"
    exit 0
fi


## 安装 Java
yum update -y

## Corretto 25
yum install -y java-25-amazon-corretto java-25-amazon-corretto-devel python3-pip git
pip3 install dool

## 启动 spring-petclinic 应用
cd /root/
git clone https://github.com/spring-projects/spring-petclinic.git
cd spring-petclinic
export HOME=/root/
./mvnw package
cp target/*.jar /usr/local/bin/spring-petclinic.jar

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
