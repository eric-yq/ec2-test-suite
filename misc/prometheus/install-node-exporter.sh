#!/bin/bash

sudo su - root

#########################################################################################
# 设置本地时区为上海
timedatectl set-timezone Asia/Shanghai

#########################################################################################
# 安装 Node Exporter, x86_64
wget https://github.com/prometheus/node_exporter/releases/download/v1.9.0/node_exporter-1.9.0.linux-amd64.tar.gz
tar zxf node_exporter-1.9.0.linux-amd64.tar.gz
cp node_exporter-1.9.0.linux-amd64/node_exporter /usr/local/bin/

# 安装 Node Exporter, arm64
wget https://github.com/prometheus/node_exporter/releases/download/v1.9.0/node_exporter-1.9.0.linux-arm64.tar.gz
tar zxf node_exporter-1.9.0.linux-arm64.tar.gz
cp node_exporter-1.9.0.linux-arm64/node_exporter /usr/local/bin/

# 创建 systemd 服务
sudo tee /etc/systemd/system/node_exporter.service > /dev/null << EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter
systemctl status node_exporter

#########################################################################################
# 安装 Redis Exporter
# 获取系统架构
arch=$(uname -m)
if [ "$arch" = "x86_64" ]; then
    ARCH="amd64"
elif [ "$arch" = "aarch64" ]; then
    ARCH="arm64"
else
    echo "Unknown: $arch"
fi

cd /tmp/
wget https://github.com/oliver006/redis_exporter/releases/download/v1.70.0/redis_exporter-v1.70.0.linux-$ARCH.tar.gz
tar -xvf redis_exporter-*.linux-*.tar.gz
chown -R root:root redis_exporter-*/
cp redis_exporter-*/redis_exporter /usr/local/bin/
redis_exporter --version

cat > /etc/systemd/system/redis_exporter.service <<EOF
[Unit]
Description=Redis Exporter
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/redis_exporter \
  --redis.addr=localhost:6379 \
  --web.listen-address=:9121
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
systemctl daemon-reload
systemctl enable redis_exporter --now
systemctl status redis_exporter

# 在 Prometheus 中添加 Redis Exporter
cat >> /usr/local/prometheus/prometheus.yml << EOF

# 自定义配置
  - job_name: 'ec2_nodes_redis'
    ec2_sd_configs:
        - region: '$(cloud-init query region)'
    relabel_configs:
        - source_labels: [__meta_ec2_instance_state]
          regex: running
          action: keep
        - source_labels: [__meta_ec2_private_ip]
          target_label: __address__
          replacement: '\${1}:9121'
EOF
curl -X POST http://localhost:9090/-/reload

# 添加 Redis Exporter 的 dashboard
# https://grafana.com/grafana/dashboards/14091-redis-dashboard-for-prometheus-redis-exporter-1-x/


#########################################################################################
# 