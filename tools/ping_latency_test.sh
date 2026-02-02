#!/bin/bash

HOST="$1"

echo "测试 MySQL Client-Server 延迟 (ping 60 次)"
echo "=========================================="
ping -q -c 60 $HOST 
echo "=========================================="