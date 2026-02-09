#/bin/bash

### For xxd.xlarge 实例，例如 r6id, r7gd 等。

INSTYPE=$1
COUNT=$2
WORKLOAD=$3

# AeroSpike 集群公共配置
# 获取子网 ID和安全组 ID
INSTANCE_ID=$(ec2-metadata --quiet --instance-id)
REGION=$(ec2-metadata --quiet --region)
SGID=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --region $REGION \
  --query 'Reservations[0].Instances[0].SubnetId' \
  --output text)
SUBID=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --region $REGION \
  --query 'Reservations[0].Instances[0].SecurityGroups[*].GroupId' \
  --output text)
  
# AWS EC2 实例配置
# INSTYPE=$1
# COUNT=$2
INSFAMILY=$(echo $INSTYPE | cut -d'.' -f1)
NAME="cluster_$INSFAMILY"
DISKS="type=gp3,size=80"
DISTRO="amazon"
DISTROVERSION="2023"
INSARCH=$(aws ec2 describe-instance-types \
  --instance-types $INSTYPE \
  --query "InstanceTypes[0].ProcessorInfo.SupportedArchitectures" \
  --output text)
AMIID=$(aws ssm get-parameter \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-$INSARCH \
  --region $REGION --query Parameter.Value --output text)
echo $REGION $MAC $SGID $SUBID $AMIID

# Aerospike 配置
VERSION="7.2.0.8c"

# 创建集群
aerolab config backend -t aws -p /root/.aerolab -r $REGION
aerolab cluster destroy --force --name $NAME 
sleep 5
aerolab cluster create \
  --name $NAME \
  --count $COUNT \
  --instance-type $INSTYPE \
  --ami $AMIID \
  --aws-disk $DISKS \
  --secgroup-id $SGID \
  --subnet-id $SUBID \
  --distro $DISTRO --distro-version $DISTROVERSION \
  --aerospike-version $VERSION \
  --aws-expire 0 \
  --start n

echo "[Info] Sleep 300s to wait instance reboot automatically ......"
sleep 300

## 查询本地磁盘大小
NVME_SIZE_GB=$(aws ec2 describe-instance-types --instance-types $INSTYPE --query "InstanceTypes[0].InstanceStorageInfo.Disks[0].SizeInGB" --output text)

if [ $NVME_SIZE_GB -lt 2000 ]; then
    PCT=" "
    PTNUM="0"
elif [ $NVME_SIZE_GB -ge 2000 ] && [ $NVME_SIZE_GB -lt 4000 ]; then
    PCT="-p 50,50"
    PTNUM="1"
elif [ $NVME_SIZE_GB -ge 4000 ] && [ $NVME_SIZE_GB -lt 8000 ]; then
    PCT="-p 25,75"
    PTNUM="1"
else
    echo "not supported"
    exit 1  # 可选：如果需要在不支持的情况下退出脚本
fi

echo "NVME_SIZE_GB = $NVME_SIZE_GB, Percentage of partitions= $PCT. "

# 添加本地盘分区，只使用第一块盘。
# 实例：r6id, r7gd, i3 等，单盘容量 1900GB，
## i3.8xlarge:    4 x 1900 NVMe SSD
## i3.16xlarge:   8 x 1900 NVMe SSD (独占一个socket)
## r6id.8xlarge:  1 x 1900 NVMe SSD
## r6id.16xlarge: 2 x 1900 NVMe SSD (独占一个socket)
# i4i/i4g/i8g 实例，单盘容量 3750GB，
## i4i/i4g/i8g.8xlarge:  2 x 3750 NVMe SSD
## i4i/i4g/i8g.16xlarge: 4 x 3750 NVMe SSD
# i3en, im4gn, is4gen 实例，单盘容量 7500GB，
## i4i/i4g/i8g.8xlarge:  2 x 3750 NVMe SSD
## i4i/i4g/i8g.16xlarge: 4 x 3750 NVMe SSD
aerolab cluster partition create --name $NAME --filter-type=nvme --filter-disks=1 $PCT
aerolab cluster partition conf   --name $NAME --namespace=test --filter-type=nvme --filter-disks=1 --filter-partitions=$PTNUM --configure=memory


# 启动集群
aerolab aerospike restart --name $NAME
sleep 30

# 查看状态
aerolab inventory list
aerolab attach shell --name $NAME -- asadm -e info
aerolab attach shell --name $NAME --node=all -- "yum install -yq htop python3-pip && pip3 install dool"

# load data
cd /root/ycsb-aerospike-binding-0.17.0/
mkdir -p results
RESULT_FILE=/root/ycsb-aerospike-binding-0.17.0/results/$NAME-ycsb-load.txt
RESULT_FILE1=/root/ycsb-aerospike-binding-0.17.0/results/$NAME-ycsb-run.txt
echo "[Info] Load data ..." >> ${RESULT_FILE}

IPADDR=$(aerolab attach shell --name $NAME -- asinfo -v "service" | cut -d':' -f1)
/root/ycsb-aerospike-binding-0.17.0/bin/ycsb load aerospike -s \
  -P /root/ycsb-aerospike-binding-0.17.0/workloads/$WORKLOAD \
  -p as.host=$IPADDR   \
  -p as.namespace=test \
  -p aerospike.timeout=5000 \
  -p aerospike.retries=3 \
  -p aerospike.retryDelay=100 \
  -threads 256 >> ${RESULT_FILE}

sleep 30

# run benchmark
THREADS="50 100 200 400 600 800 1000"
for i in $THREADS
do
    echo "[Info] Run benchmark , thread=$i ..." >> ${RESULT_FILE1}
    /root/ycsb-aerospike-binding-0.17.0/bin/ycsb run aerospike -s \
      -P /root/ycsb-aerospike-binding-0.17.0/workloads/$WORKLOAD \
      -p as.host=$IPADDR \
      -p as.namespace=test \
      -p aerospike.timeout=3000 \
      -p aerospike.retries=3 \
      -p aerospike.retryDelay=100 \
      -threads $i  >> ${RESULT_FILE1}
		
    sleep 10
done

echo "[Info] Complete benchmark on $NAME. " >> ${RESULT_FILE1}

# 释放集群
aerolab cluster destroy --force --name $NAME 
