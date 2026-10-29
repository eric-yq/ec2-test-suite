#!/bin/bash

# Ubuntu 22.04

sudo su - root

######################################################################################################
# 1. 安装 ollama
curl -fsSL https://ollama.com/install.sh | bash
systemctl status  ollama
systemctl stop    ollama
systemctl disable ollama

echo "export OLLAMA_HOST=0.0.0.0:11434" >> /etc/profile
source /etc/profile

cd /root/
nohup ollama serve &

# 安装 embedding 模型
ollama pull bge-m3

######################################################################################################
# 2. 安装 dify
cd /root/
apt install docker docker-compose python3-pip -y
pip3 install dool
git clone https://github.com/langgenius/dify.git --branch 1.0.0
cd dify/docker
cp .env.example .env
# 修改一下 web ui 的端口号：5555
sed -i 's/EXPOSE_NGINX_PORT=80/EXPOSE_NGINX_PORT=5555/g' .env

docker-compose up -d
docker-compose ps -a
#          Name                       Command                  State                                         Ports                                   
# ---------------------------------------------------------------------------------------------------------------------------------------------------
# docker_api_1             /bin/bash /entrypoint.sh         Up             5001/tcp                                                                  
# docker_db_1              docker-entrypoint.sh postg ...   Up (healthy)   0.0.0.0:5432->5432/tcp,:::5432->5432/tcp                                  
# docker_nginx_1           sh -c cp /docker-entrypoin ...   Up             0.0.0.0:443->443/tcp,:::443->443/tcp, 0.0.0.0:5555->80/tcp,:::5555->80/tcp
# docker_plugin_daemon_1   /bin/bash -c /app/entrypoi ...   Up             0.0.0.0:5003->5003/tcp,:::5003->5003/tcp                                  
# docker_redis_1           docker-entrypoint.sh redis ...   Up (healthy)   6379/tcp                                                                  
# docker_sandbox_1         /main                            Up (healthy)                                                                             
# docker_ssrf_proxy_1      sh -c cp /docker-entrypoin ...   Up             3128/tcp                                                                  
# docker_weaviate_1        /bin/weaviate --host 0.0.0 ...   Up                                                                                       
# docker_web_1             /bin/sh ./entrypoint.sh          Up             3000/tcp                                                                  
# docker_worker_1          /bin/bash /entrypoint.sh         Up             5001/tcp                                                                  
# root@ip-172-31-34-251:~/dify/docker# 

echo "Web UI: http://$(ec2-metadata --quiet --public-ipv4):5555"

######################################################################################################
# 3. 在另一个 c8g.4xlarge 实例上安装 deepseek-r1-distiteld 
curl -fsSL https://ollama.com/install.sh | bash
systemctl status  ollama
systemctl stop    ollama
systemctl disable ollama

echo "export OLLAMA_HOST=0.0.0.0:11434" >> /etc/profile
source /etc/profile

cd /root/
nohup ollama serve &

# 安装 deepseek 模型
ollama run deepseek-r1:7b
# 或者
ollama run deepseek-r1:14b