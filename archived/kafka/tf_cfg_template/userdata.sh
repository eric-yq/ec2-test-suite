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
    echo "等待 3 分钟，然后启动 userdata.service 服务执行后续安装过程。"

    ### 如果 3 分钟之后，实例没有重启，或者也有可能不需要重启，则开始启动服务执行后续安装过程。
    sleep 180
    systemctl start userdata.service
    systemctl disable userdata.service
    exit 0
fi

## 安装 Java
yum update -y
yum install -yq java-17-amazon-corretto java-17-amazon-corretto-devel python3-pip git
pip install dool
cd /root/
wget -q https://dlcdn.apache.org/kafka/3.9.0/kafka_2.13-3.9.0.tgz
tar -xzf kafka_2.13-3.9.0.tgz
mv kafka_2.13-3.9.0 /usr/local/kafka
cd /usr/local/kafka
 
# 修改配置文件
AAA="log.dirs=\/tmp\/kraft-combined-logs"
# BBB="log.dirs=\/mnt\/$disk\/kraft-combined-logs"
BBB="log.dirs=\/root\/kafka-data\/kraft-combined-logs"
sed -i.bak "s/$AAA/$BBB/g" config/kraft/reconfig-server.properties
sed -i "s/num.partitions=1/num.partitions=3/g" config/kraft/reconfig-server.properties
sed -i "s/localhost/$(hostname -i)/g" config/kraft/reconfig-server.properties
# diff config/kraft/reconfig-server.properties*

# 初始化
KAFKA_CLUSTER_ID="$(bin/kafka-storage.sh random-uuid)"
bin/kafka-storage.sh format --standalone -t $KAFKA_CLUSTER_ID -c config/kraft/reconfig-server.properties

sleep 5

#创建 systemd 服务文件:
cat << EOF > /etc/systemd/system/kafka.service
[Unit]
Description=Kafka service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/kafka/bin/kafka-server-start.sh /usr/local/kafka/config/kraft/reconfig-server.properties
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 启用并启动服务:
systemctl daemon-reload
systemctl enable kafka.service
systemctl start kafka.service

# 创建 Topic 
bin/kafka-topics.sh --create   --topic quickstart-events --bootstrap-server localhost:9092
bin/kafka-topics.sh --describe --topic quickstart-events --bootstrap-server localhost:9092
## 如果远程连接，使用 broker-ip 替换 localhost

systemctl disble userdata.service
