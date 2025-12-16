#!/bin/bash 

# Amazon Linux 2023
sudo su - root

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

# 如果只使用一块 instancestore 磁盘的话，可以选用上面循环的最后一个 $disk


## 安装必要的一些软件包。
yum install -y java-11-amazon-corretto python3-pip git
pip install dool

# 更新 maven
cd /root/
VER=3.9.11
wget https://dlcdn.apache.org/maven/maven-3/${VER}/binaries/apache-maven-${VER}-bin.tar.gz
tar zxf apache-maven-${VER}-bin.tar.gz -C /usr/ --strip-components 1
mvn -v

# 安装 Kafka UI
yum install -y docker
systemctl start docker
docker run -d -p 5001:8080 -e DYNAMIC_CONFIG_ENABLED=true provectuslabs/kafka-ui

########################################################################################################
## Benchmark  with openmessaging benchmark
## https://github.com/openmessaging/benchmark
## https://openmessaging.cloud/docs/benchmarks/kafka/

# 构建 benchmark 工具
cd /root/
# git clone https://github.com/openmessaging/openmessaging-benchmark
git clone https://github.com/openmessaging/benchmark.git openmessaging-benchmark
cd openmessaging-benchmark/
mvn clean verify -e

# 执行 benchmark 的函数
#####################################################################
#!/bin/bash
# run.sh
run_benchmark() {
	# 设置要测试的 Kafka 规格和 workload
	INSTYPE="$1"
	IPADDR="$2"
	WORKLOAD="$3"
	
	# 修改 driver文件的配置，Kafka server 地址
	DRIVER_FOLDER="driver-kafka-${INSTYPE}-${IPADDR}"
	rm -rf ${DRIVER_FOLDER}
	cp -r  driver-kafka ${DRIVER_FOLDER}
	sed -i "s/localhost/$IPADDR/g" ${DRIVER_FOLDER}/kafka-*.yaml
	sed -i "s/replicationFactor: 3/replicationFactor: 1/g" ${DRIVER_FOLDER}/kafka-*.yaml
	sed -i "s/min.insync.replicas=2/min.insync.replicas=1/g" ${DRIVER_FOLDER}/kafka-*.yaml
	
	# 执行 benchmark
	XXX=$(grep testDurationMinutes workloads/$WORKLOAD.yaml | awk -F " " '{print $2}')
	let YYY=(XXX+1)*60+30
	TIMESTAMP=$(date +%Y%m%d%H%M%S)
	RESULT_PATH=./result-${INSTYPE}-${IPADDR}-${TIMESTAMP}
	OUTPUT_LOG=${RESULT_PATH}/output_$INSTYPE_$WORKLOAD.log
	mkdir -p ${RESULT_PATH}
	
	echo "[INFO] Start to run benchmark: $INSTYPE, $IPADDR, $WORKLOAD"
	echo "[Info] testDurationMinutes: $XXX minutes, and benchmark will be stopped after $YYY [($XXX+1)*60+30)] seconds."
	
	timeout ${YYY}s bin/benchmark \
	  --drivers ${DRIVER_FOLDER}/kafka-throughput.yaml workloads/$WORKLOAD.yaml \
	  --output ${RESULT_PATH}/output.json > ${OUTPUT_LOG}
	
	sleep 3
	
	# 生成 csv 结果文件
	echo "[INFO] Start to generate csv result file."
	bin/benchmark --csv ./${RESULT_PATH}
	
	# 保存日志和结果文件
	mv ${DRIVER_FOLDER} benchmark-worker.log results-*.csv ${RESULT_PATH}/
	
	echo "[INFO] Complete to run benchmark."
}
run_benchmark $1 $2 $3
#####################################################################
# 执行上面脚本
bash run.sh r7gd.2xlarge 172.31.11.94 simple-workload

# run_bnchmark i3.2xlarge   172.31.47.75 simple-workload
# run_benchmark i4g.2xlarge  172.31.44.179 simple-workload
# run_benchmark i4i.2xlarge  172.31.41.71 simple-workload
# run_benchmark i7ie.2xlarge 172.31.45.2 simple-workload
# run_benchmark i8g.2xlarge  172.31.38.141 simple-workload

# workload:max-rate-10-topics-1-partition-1kb
run_benchmark i3.2xlarge   172.31.47.75 max-rate-10-topics-1-partition-1kb
run_benchmark i4g.2xlarge  172.31.44.179 max-rate-10-topics-1-partition-1kb
run_benchmark i4i.2xlarge  172.31.41.71 max-rate-10-topics-1-partition-1kb
run_benchmark i7ie.2xlarge 172.31.45.2 max-rate-10-topics-1-partition-1kb
run_benchmark i8g.2xlarge  172.31.38.141 max-rate-10-topics-1-partition-1kb

# workload:max-rate-10-topics-1-partition-100b
run_benchmark i3.2xlarge   172.31.47.75 max-rate-10-topics-1-partition-100b
run_benchmark i4g.2xlarge  172.31.44.179 max-rate-10-topics-1-partition-100b
run_benchmark i4i.2xlarge  172.31.41.71 max-rate-10-topics-1-partition-100b
run_benchmark i7ie.2xlarge 172.31.45.2 max-rate-10-topics-1-partition-100b
run_benchmark i8g.2xlarge  172.31.38.141 max-rate-10-topics-1-partition-100b

  
####### 下面的先忽略吧。 ##############

# 安装terraform，ansible 等工具
cd /root/
# yum install -y yum-utils
# yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
# yum -y install terraform
wget https://releases.hashicorp.com/terraform/0.10.8/terraform_0.10.8_linux_amd64.zip
wget https://github.com/adammck/terraform-inventory/releases/download/v0.10/terraform-inventory_v0.10_linux_amd64.zip
unzip terraform_0.10.8_linux_amd64.zip -d /usr/bin/
unzip terraform-inventory_v0.10_linux_amd64.zip -d /usr/local/bin/
yum install -y ansible
# terraform --version
# terraform-inventory --version

# 配置 AWS CLI
...

# 生成密钥
ssh-keygen -f ~/.ssh/kafka_aws
# ls ~/.ssh/kafka_aws*
# /root/.ssh/kafka_aws  /root/.ssh/kafka_aws.pub


cd /root/openmessaging-benchmark/driver-kafka/deploy
cp -r ssd-deployment ssd-deployment-$INSTYPE
cd ssd-deployment-$INSTYPE

# 获取一些环境信息
REGION=$(cloud-init query ds.meta_data.placement.region)
AZ=$(cloud-init query ds.meta_data.placement.availability-zone)

# 查询 AL2023 最新AMI ID
ARCH_KAFKA=$(aws ec2 describe-instance-types --instance-types $INSTYPE --query 'InstanceTypes[*].ProcessorInfo.SupportedArchitectures' --output text)
AMI_KAFKA=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-$ARCH_KAFKA --region $REGION --query Parameter.Value --output text)
ARCH_CLIENT=$(aws ec2 describe-instance-types --instance-types $CLINET_EC2_SIZE --query 'InstanceTypes[*].ProcessorInfo.SupportedArchitectures' --output text)
AMI_CLIENT=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-$ARCH_CLIENT --region $REGION --query Parameter.Value --output text)

# 生成配置文件
mv terraform.tfvars terraform.tfvars.bak
cat > terraform.tfvars  << EOF
public_key_path = "~/.ssh/kafka_aws.pub"
region          = "$REGION"
az              = "$AZ"
ami             = "$AMI_KAFKA"  // AL2023
ami-client      = "$AMI_CLIENT" // AL2023

instance_types = {
  "kafka"     = "$INSTYPE"
  "zookeeper" = "$INSTYPE"
  "client"    = "c6i.4xlarge"
}

num_instances = {
  "client"    = 4
  "kafka"     = 3
  "zookeeper" = 1
}
EOF
# 修改 client 的 ami
sed -i.bak '139s/var.ami/var.ami-client/' provision-kafka-aws.tf
# 添加一个变量
sed -i     '31avariable \"ami-client\" {}' provision-kafka-aws.tf

# 使用 terraform 创建资源
terraform init
terraform plan
terraform apply --auto-approve
terraform-inventory --list ./ > 

# 执行 ansible playbook
# ansible-playbook --user root --inventory `which terraform-inventory` deploy_$INSTYPE.yaml








