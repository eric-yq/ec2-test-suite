#!/bin/bash

## 暂时关闭补丁更新流程
sudo systemctl stop amazon-ssm-agent
sudo systemctl disable amazon-ssm-agent

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

    ### 等待 60 秒再执行 userdata 脚本
    sleep 60
    systemctl start userdata.service
    exit 0
fi

SUT_NAME="SUT_XXX"

yum install -y git awscli

## 配置 AWSCLI
aws_ak_value="akxxx"
aws_sk_value="skxxx"
aws_region_name=$(ec2-metadata --quiet --region)
aws configure set aws_access_key_id ${aws_ak_value}
aws configure set aws_secret_access_key ${aws_sk_value}
aws configure set default.region ${aws_region_name}
aws_s3_bucket_name=$(aws s3 ls | awk '{print $3}' | grep ec2-core-benchmark | head -1)

## 获取代码
cd /root/
git clone https://github.com/eric-yq/ec2-test-suite.git

# 安装 SUT
cd ec2-test-suite/${SUT_NAME}
bash install-sut.sh ${SUT_NAME}

# 执行 benchmark
cd /root/ec2-test-suite/benchmark
bash milvus-benchmark-local.sh 127.0.0.1 Performance768D1M

## Disable 服务，这样 reboot 后不会再次执行
systemctl disable userdata.service

# 停止实例
INSTANCE_ID=$(ec2-metadata --quiet --instance-id)
REGION_ID=$(ec2-metadata --quiet --region)
# aws ec2 terminate-instances --instance-ids "${INSTANCE_ID}" --region "${REGION_ID}"