#!/bin/bash

echo "This is a blank EC2 instance userdata script. No actions performed."

## 暂时关闭补丁更新流程
sudo systemctl stop amazon-ssm-agent
sudo systemctl disable amazon-ssm-agent
