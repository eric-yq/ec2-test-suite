#!/bin/bash

sudo su - root

#########################################################################################
# 安装 Prometheus Server
cd /tmp/
wget https://github.com/prometheus/prometheus/releases/download/v3.2.0/prometheus-3.2.0.linux-amd64.tar.gz
tar -xvf prometheus-3.2.0.linux-amd64.tar.gz
mv prometheus-3.2.0.linux-amd64 /usr/local/prometheus
chown -R root:root /usr/local/prometheus

# 创建 systemd 服务
cat > /etc/systemd/system/prometheus.service << EOF
[Unit]
Description=Prometheus
After=network.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/prometheus/prometheus \
    --web.enable-lifecycle  \
    --config.file /usr/local/prometheus/prometheus.yml \
    --storage.tsdb.path /usr/local/prometheus/data/

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus
systemctl status prometheus

# 添加 EC2 实例的动态发现
cat >> /usr/local/prometheus/prometheus.yml << EOF

# 自定义配置
  - job_name: 'ec2_nodes'
    ec2_sd_configs:
        - region: '$(cloud-init query region)'
    relabel_configs:
        - source_labels: [__meta_ec2_instance_state]
          regex: running
          action: keep
        - source_labels: [__meta_ec2_private_ip]
          target_label: __address__
          replacement: '\${1}:9100'
EOF
systemctl restart prometheus
systemctl status prometheus

#########################################################################################
## 安装 Grafana：找一个数字比较吉利的版本好，比如 86168 ... 
yum install -y https://dl.grafana.com/enterprise/release/grafana-enterprise-nightly_12.0.0-86168_86168_linux_amd64.rpm
systemctl enable grafana-server.service --now
systemctl status grafana-server.service 

#########################################################################################
## 添加 dashboard （node）
## https://grafana.com/grafana/dashboards/1860-node-exporter-full/ 


