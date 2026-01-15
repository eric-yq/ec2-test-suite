#!/bin/bash

HOST="$1"
USER="root"
PASSWORD="gv2mysql"
COUNT=1000

echo "测试 MySQL Client-Server 延迟 (执行 $COUNT 次)"
echo "=========================================="

# 使用 time 命令测试
total_time=0

for i in $(seq 1 $COUNT); do
    start=$(date +%s%N)
    mysql -h $HOST -u $USER -p$PASSWORD -e "SELECT 1" > /dev/null 2>&1
    end=$(date +%s%N)
    
    elapsed=$((($end - $start) / 1000000))  # 转换为毫秒
    total_time=$(($total_time + $elapsed))
    
    if [ $(($i % 100)) -eq 0 ]; then
        echo "已完成: $i/$COUNT"
    fi
done

avg_latency=$(($total_time / $COUNT))
echo ""
echo "平均延迟: ${avg_latency} ms"