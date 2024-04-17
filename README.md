Some benchmark test suites for AWS EC2 instance.


## 定义需要替换的变量的值
REGION_NAME="us-west-2"
SUBNET_ID="subnet-046de201cd71d1cde"
SG_ID="sg-0d75ecd997cb2a4b4"
SUT_NAME="nginx"

## 替换
cd /root/ec2-test-suite/$SUT_NAME/tf_cfg_template
sed -i "s/subnet-025096aa4e2c8c3f3/$SUBNET_ID/g"  variables.tf 
sed -i "s/sg-066af1ddd6d0624d9/$SG_ID/g"  variables.tf 
sed -i "s/us-east-2/$REGION_NAME/g"  variables.tf 

## 替换 Benchmark 脚本中的 us-east-2 等信息
cd /root/ec2-test-suite/benchmark
REGION_NAME="us-west-2"
sed -i "s/us-east-2/$REGION_NAME/g" *