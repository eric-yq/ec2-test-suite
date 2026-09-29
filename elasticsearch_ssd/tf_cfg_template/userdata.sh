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

    ### 等待 180 秒再执行 userdata 脚本
    sleep 180
    systemctl start userdata.service
    exit 0
fi

################################################################################################################ 

SUT_NAME="SUT_PTS_SSD"

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

# 设置磁盘lvm stripe
cd /root/
yum install -yq git
git clone https://github.com/eric-yq/ec2-test-suite.git
bash ec2-test-suite/tools/setup_nvme_instance_store.sh
# 如果有本地盘，脚本执行后挂载到 /data；如果没有本地盘，则脚本退出。


## 设置一些系统参数
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 131072" >> /etc/security/limits.conf
echo "* soft nproc 4096" >> /etc/security/limits.conf
echo "* hard nproc 4096" >> /etc/security/limits.conf
echo "vm.max_map_count=262145" >> /etc/sysctl.conf
sysctl -p 
echo always > /sys/kernel/mm/transparent_hugepage/enabled
echo always > /sys/kernel/mm/transparent_hugepage/defrag

# ElasticSearch 安装信息
VERSION="8.19.22"
esuser="ec2-user"
IPADDR="$(hostname -i)"
NODENAME=node-$RANDOM
ESROOTDISK="/data"  

# 安装目录
cd /root/
ARCH=$(arch)
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${VERSION}-linux-${ARCH}.tar.gz
tar zxf elasticsearch-${VERSION}-linux-${ARCH}.tar.gz
mv elasticsearch-${VERSION} $ESROOTDISK/elasticsearch
mkdir -p $ESROOTDISK/elasticsearch/data
mkdir -p $ESROOTDISK/elasticsearch/logs
chown -R $esuser:$esuser $ESROOTDISK/elasticsearch

## 生成 ES 配置文件
cat << EOF > $ESROOTDISK/elasticsearch/config/elasticsearch.yml
# ==========================================================
# Elasticsearch 8.19.x — 单机 benchmark 配置
# ==========================================================

# ---------- 集群与节点 ----------
cluster.name: es-bench
node.name: node-26723

# 只保留必要角色: 去掉 ml / transform 减少后台开销;
# 保留 ingest —— 部分 Rally track 会用 ingest pipeline, 缺这个角色会失败
node.roles: [ master, data, ingest ]

# ---------- 单机发现 ----------
# 用 single-node 直接跳过选主流程, 不要再配 initial_master_nodes / seed_hosts
discovery.type: single-node

# ---------- 网络 ----------
network.host: ${IPADDR}
http.port: 9200

# ---------- 路径 ----------
# 确认这是本地 NVMe 挂载点, 不是 EBS 根卷
path.data: $ESROOTDISK/elasticsearch/data
path.logs: $ESROOTDISK/elasticsearch/logs

# ---------- 安全: 关闭, 让 Rally 走明文 HTTP ----------
xpack.security.enabled: false

# ---------- 关掉 benchmark 不需要的后台组件, 降低噪声 ----------
xpack.ml.enabled: false
xpack.watcher.enabled: false
xpack.monitoring.collection.enabled: false

# ---------- 内存 ----------
bootstrap.memory_lock: false

# ---------- 索引写入 ----------
indices.memory.index_buffer_size: 30%

# ---------- 熔断器: 避免压测中被误触发中断测试 ----------
indices.breaker.total.use_real_memory: false
indices.breaker.fielddata.limit: 70%
indices.fielddata.cache.size: 40%

# ---------- 查询 ----------
indices.query.bool.max_clause_count: 2048

# ---------- 磁盘水位: 大数据集 track 必调 ----------
# 默认 flood_stage 95% 触发后索引变只读, benchmark 会直接失败
cluster.routing.allocation.disk.threshold_enabled: true
cluster.routing.allocation.disk.watermark.low: 90%
cluster.routing.allocation.disk.watermark.high: 95%
cluster.routing.allocation.disk.watermark.flood_stage: 97%
EOF

# 启动 
su ${esuser} -c "$ESROOTDISK/elasticsearch/bin/elasticsearch -d -p pid"
echo "[$(date)] Wait for ElasticSearch start successfully."
sleep 10
curl -XGET http://$IPADDR:9200/_cat/health?v



## 停止并清理数据：先停止其他节点，最后停止 master节点
# kill -9 $(cat /home/${esuser}/elasticsearch/pid)
# rm -rf /home/${esuser}/elasticsearch/data

# IPADDR=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | awk -F " " '{print $2}')
# IPADDR=$(hostname -i)


## Disable 服务，这样 reboot 后不会再次执行
systemctl disable userdata.service