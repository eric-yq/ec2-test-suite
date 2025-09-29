#!/bin/bash

# JMeter压测环境安装和配置脚本 - Amazon Linux 2023

echo "=== 安装Java 11 ==="
sudo dnf update -y
sudo dnf install -y java-11-amazon-corretto-headless

echo "=== 下载和安装JMeter ==="
cd /opt
sudo wget https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-5.4.1.tgz
sudo tar -xzf apache-jmeter-5.4.1.tgz
sudo ln -s apache-jmeter-5.4.1 jmeter
sudo chown -R ec2-user:ec2-user /opt/apache-jmeter-5.4.1

echo "=== 设置环境变量 ==="
echo 'export JMETER_HOME=/opt/jmeter' >> ~/.bashrc
echo 'export PATH=$PATH:$JMETER_HOME/bin' >> ~/.bashrc
source ~/.bashrc

echo "=== JMeter安装完成 ==="
echo "使用以下命令进行压测："
echo "200并发: /opt/jmeter/bin/jmeter -n -t test-plan.jmx -l results-200.jtl -e -o report-200 -Jusers=200"
echo "300并发: /opt/jmeter/bin/jmeter -n -t test-plan.jmx -l results-300.jtl -e -o report-300 -Jusers=300"
