#!/bin/bash

# JMeter压测执行脚本
# 使用方法: ./run-jmeter-test.sh <目标服务器IP>

if [ $# -eq 0 ]; then
    echo "使用方法: $0 <目标服务器IP>"
    echo "示例: $0 10.0.1.100"
    exit 1
fi

TARGET_HOST=$1
JMETER_HOME=/opt/jmeter

echo "=== 开始压测目标服务器: $TARGET_HOST ==="

echo "=== 200并发压测 ==="
$JMETER_HOME/bin/jmeter -n -t test-plan.jmx \
    -l results-200.jtl \
    -e -o report-200 \
    -Jusers=200 \
    -Jhost=$TARGET_HOST \
    -Jport=8080

echo "=== 300并发压测 ==="
$JMETER_HOME/bin/jmeter -n -t test-plan.jmx \
    -l results-300.jtl \
    -e -o report-300 \
    -Jusers=300 \
    -Jhost=$TARGET_HOST \
    -Jport=8080

echo "=== 压测完成 ==="
echo "200并发结果报告: report-200/index.html"
echo "300并发结果报告: report-300/index.html"

echo "=== 快速查看结果 ==="
echo "200并发统计:"
tail -n +2 results-200.jtl | awk -F',' '{
    total++; 
    if($8=="true") success++; 
    sum+=$2
} END {
    print "总请求数:", total
    print "成功率:", (success/total)*100"%"
    print "平均响应时间:", sum/total"ms"
    print "TPS:", total/((NR>1?$1-start:0)/1000)
}' start=$(head -2 results-200.jtl | tail -1 | cut -d',' -f1)

echo ""
echo "300并发统计:"
tail -n +2 results-300.jtl | awk -F',' '{
    total++; 
    if($8=="true") success++; 
    sum+=$2
} END {
    print "总请求数:", total
    print "成功率:", (success/total)*100"%"
    print "平均响应时间:", sum/total"ms"
    print "TPS:", total/((NR>1?$1-start:0)/1000)
}' start=$(head -2 results-300.jtl | tail -1 | cut -d',' -f1)
