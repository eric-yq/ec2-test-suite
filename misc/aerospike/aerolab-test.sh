aerolab config backend -t aws \
  -p /root/.aerolab \
  -r us-east-1
  
  
NAME="testcluster"
COUNT=1
INSTYPE="c6i.large"
AMIID="ami-01816d07b1128cd2d"
DISKS="type=gp3,size=20"
SGID="sg-09ef5e0e71036bf05"
SUBID="subnet-014f5c982074a52ba"
DISTRO="amazon"
DISTROVERSION="2023"
VERSION="7.2.0c"


## 创建集群
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
  --public-ip \
  
## 释放集群
aerolab cluster destroy --name testcluster 

## 查看
aerolab attach shell --name testcluster -- asadm -e info