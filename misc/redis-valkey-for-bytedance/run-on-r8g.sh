#!/bin/bash

# 使用 1 个 c7gn.16xlarge 进行测试

SUT_IP_ADDR="172.31.14.226"
THREADS=1

# r8g.24xlarge, redis, 300 clients
SUT_NAME="redis"
PORT=6379
CONNECTIONS=300
bash benchmark.sh $SUT_NAME $SUT_IP_ADDR $PORT $THREADS $CONNECTIONS

# r8g.24xlarge, redis, 3000 clients, 
SUT_NAME="redis"
PORT=6379
CONNECTIONS=3000
bash benchmark.sh $SUT_NAME $SUT_IP_ADDR $PORT $THREADS $CONNECTIONS

# r8g.24xlarge, valkey, 300 clients
SUT_NAME="valkey"
PORT=16379
CONNECTIONS=300
bash benchmark.sh $SUT_NAME $SUT_IP_ADDR $PORT $THREADS $CONNECTIONS

# r8g.24xlarge, valkey, 3000 clients
SUT_NAME="valkey"
PORT=16379
CONNECTIONS=3000
bash benchmark.sh $SUT_NAME $SUT_IP_ADDR $PORT $THREADS $CONNECTIONS
