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
	echo "UUID=$UUID $MOUNTDIR xfs  defaults,nofail  0  2" >> /etc/fstab
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

### 执行benchmark 
bash benchmark/mongo-benchmark_v2.sh $IPADDR


