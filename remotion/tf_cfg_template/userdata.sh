#!/bin/bash
# 统一日志去处:两条调用路径(cloud-init 首次 / systemd 重启后)都写同一个文件

exec >> /var/log/userdata.log 2>&1
echo "=== userdata start $(date -Is) boot=$(cat /proc/sys/kernel/random/boot_id | head -c8) ==="

SENTINEL=/root/.userdata-done

# ---------- 首次启动:自我注册成开机服务,然后给重启一个机会 ----------
if [ ! -f "/root/userdata.sh" ]; then
    echo "首次启动,安装 userdata.service"
    cp "$0" /root/userdata.sh        # 用 $0,不写死 part-001
    chmod +x /root/userdata.sh

    cat > /etc/systemd/system/userdata.service <<'EOF'
[Unit]
Description=Execute userdata script at boot
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
ExecStart=/root/userdata.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable userdata.service

    # 给自动更新的重启留 10 分钟:
    #   重启了   -> 本进程随机器消失,服务在新 boot 自动跑(这才是主路径)
    #   没重启   -> 说明大概率是 AL2023,自己触发
    echo "等待 600s,给自动重启留出窗口"
    sleep 600
    echo "600s 内未重启,主动触发 userdata.service"
    systemctl start userdata.service
    exit 0
fi

# ---------- 真实工作:只跑一次 ----------
if [ -f "$SENTINEL" ]; then
    echo "已执行过($(cat "$SENTINEL")),跳过"
    exit 0
fi

set -x

#=========================================================

SUT_NAME="SUT_XXX"

# 配置 AWSCLI
cd /root/
yum remove -y awscli
ARCH=$(arch)
curl "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
cp -rf /usr/local/bin/aws /usr/bin/aws
aws --version

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

cd ec2-test-suite/${SUT_NAME}
bash install-sut.sh ${SUT_NAME}

## Disable 服务，这样 reboot 后不会再次执行
systemctl disable userdata.service

# ... 其余工作 ...

# 完成标记:既防跨 boot 重跑,也给编排侧一个明确信号
date -Is > "$SENTINEL"
echo "=== userdata done $(date -Is) ==="
