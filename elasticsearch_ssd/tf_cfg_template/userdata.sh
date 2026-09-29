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

SUT_NAME="SUT_ELASTICSEARCH_SSD"

# ---------- 1. sysctl(覆盖 RPM 自带的 262144) ----------
cat > /etc/sysctl.d/99-elasticsearch-bench.conf <<'EOF'
vm.max_map_count = 1048576
vm.swappiness = 1
net.core.somaxconn = 4096
EOF
sysctl --system

# ---------- 2. THP:开大页,不碰 defrag ----------
echo always > /sys/kernel/mm/transparent_hugepage/enabled
grep -H . /sys/kernel/mm/transparent_hugepage/{enabled,defrag}

# ---------- 3. 本地 NVMe 先挂好,再装包 ----------
# 设置磁盘lvm stripe
cd /root/
yum install -yq git
git clone https://github.com/eric-yq/ec2-test-suite.git
bash ec2-test-suite/tools/setup_nvme_instance_store.sh
# 如果有本地盘，脚本执行后挂载到 /data；如果没有本地盘，则脚本退出。

# ---------- 4. 装 ES ----------
# ElasticSearch 安装信息
VERSION="8.19.22"
esuser="elasticsearch"
IPADDR="$(hostname -i)"
NODENAME=node-$RANDOM
ESROOTDISK="/data" 

# 安装目录
mkdir -p /etc/elasticsearch/

## 生成 ES 配置文件
cat > /etc/elasticsearch/elasticsearch.yml << EOF
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

# 生成 jvm 选项
mkdir -p /etc/elasticsearch/jvm.options.d/
cat > /etc/elasticsearch/jvm.options.d/bench.options << EOF
-Xms26g
-Xmx26g
-XX:+AlwaysPreTouch
-Xlog:gc*:file=$ESROOTDISK/elasticsearch/logs/gc.log:utctime,pid,tags:filecount=8,filesize=64m
EOF

# 安装 ES
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
cat > /etc/yum.repos.d/elasticsearch.repo <<'EOF'
[elasticsearch]
name=Elasticsearch repository for 8.x packages
baseurl=https://artifacts.elastic.co/packages/8.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=0
autorefresh=1
type=rpm-md
EOF
dnf install -y --enablerepo=elasticsearch "elasticsearch-${VERSION}"
 
mkdir -p $ESROOTDISK/elasticsearch/data
mkdir -p $ESROOTDISK/elasticsearch/logs
chown -R $esuser:$esuser $ESROOTDISK/elasticsearch
chown root:elasticsearch /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/jvm.options.d/bench.options
chmod 660 /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/jvm.options.d/bench.options

# ---------- 6. 启动 ----------
systemctl daemon-reload
systemctl enable --now elasticsearch
echo "[$(date)] Wait for ElasticSearch start successfully."
sleep 10
curl -XGET http://$IPADDR:9200/_cat/health?v

## Disable 服务，这样 reboot 后不会再次执行
systemctl disable userdata.service