#!/bin/bash

# Amazon Linux 2023, and instance store.

# 查询所有需要挂载的本地盘
DISKS=$(lsblk -n -o NAME,TYPE,PTTYPE,PARTTYPE --list | grep disk | grep -v gpt | awk -F" " '{print $1}')
echo $DISKS

# 挂载数据盘
for disk in $DISKS
do
	echo "[INFO] Start to handle $disk..."
	# 格式化磁盘
	DEVICE=/dev/$disk
	mkfs -t xfs $DEVICE
	UUID=$(blkid | grep $disk| awk -F "\"" '{print $2}')
	
	# 创建挂载目录
	MOUNTDIR="/mnt/$disk"
	mkdir -p $MOUNTDIR
	
	# fstab 添加表项
		
done
# cat /etc/fstab
mount -a && df -h

## 适配mongodb的目录，使用最后一个挂的disk. 
mkdir -p /mnt/$disk/mongodb /data/
chmod 777 /mnt/$disk/mongodb
ln -s /mnt/$disk/mongodb /data/mongodb

yum install -y python3-pip htop
pip3 install dool

### 执行mongodb的install-sut.sh
# ......

### 执行benchmark 
cat << EOF > /tmp/temp-setting
export SUT_NAME="mongo"
export INSTANCE_IP_MASTER="172.31.11.114"
export INSTANCE_TYPE="i3.2xlarge"
export OS_TYPE="al2023"
EOF
source /tmp/temp-setting
nohup bash benchmark/mongo-benchmark_v2.sh ${INSTANCE_IP_MASTER} &

##################################################################################################
### 客户端，YCSB实例安装（AL2上需要Python2和JDK8环境）
# yum install -y git dmidecode htop python3-pip java-1.8.0-amazon-corretto

OS_NAME=$(egrep ^NAME /etc/os-release | awk -F "\"" '{print $2}')
OS_VERSION=$(egrep ^VERSION_ID /etc/os-release | awk -F "\"" '{print $2}')
ARCH=$(lscpu | grep Architecture | awk -F " " '{print $NF}')

## 添加 MongoDB Repo
MONGO_XY="7.0"
cat << EOF > /etc/yum.repos.d/mongodb-org-${MONGO_XY}-${ARCH}.repo
[mongodb-org-${MONGO_XY}-${ARCH}]
name=MongoDB Repository for ${MONGO_XY}-${ARCH}
baseurl=https://repo.mongodb.org/yum/amazon/${OS_VERSION}/mongodb-org/${MONGO_XY}/${ARCH}/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-${MONGO_XY}.asc
EOF

yum install -y mongodb-mongosh
git clone  https://github.com/eric-yq/ec2-test-suite.git


