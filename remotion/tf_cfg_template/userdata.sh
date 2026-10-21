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

    ### 等待 600 秒再执行 userdata 脚本
    sleep 600
    systemctl start userdata.service
    exit 0
fi

################################################################################################################ 

SUT_NAME="SUT_XXX"

apt install -y unzip amazon-ec2-utils

# 配置 AWSCLI
cd /root/
ARCH=$(arch)
curl "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
cp -rf /usr/local/bin/aws /usr/bin/aws
aws --version

aws_ak_value="akxxx"
aws_sk_value="skxxx"
# Ubuntu下 ec2-metadata 没有 --region 参数
# aws_region_name=$(ec2-metadata --quiet --region)
# Ubuntu 下还是用 cloud-init , 
aws_region_name=$(cloud-init query region)
aws configure set aws_access_key_id ${aws_ak_value}
aws configure set aws_secret_access_key ${aws_sk_value}
aws configure set default.region ${aws_region_name}
aws_s3_bucket_name=$(aws s3 ls | awk '{print $3}' | grep ec2-core-benchmark | head -1)

## 获取代码
cd /root/
git clone https://github.com/eric-yq/ec2-test-suite.git

# 执行
bash ec2-test-suite/${SUT_NAME}/install-sut.sh

## Disable 服务，这样 reboot 后不会再次执行
systemctl disable userdata.service
