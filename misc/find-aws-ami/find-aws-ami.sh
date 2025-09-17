# Amazon Linux 2023，ami-09d95d40d7748fb76
aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64 \
  --region us-east-1 --query Parameter.Value --output text

# Amazon Linux 2， ami-03f525c096fd7d7e2 (arm64)
aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-arm64-gp2 \
  --region us-east-1 --query Parameter.Value --output text
# Amazon Linux 2， ami-0023921b4fcd5382b (x86_64)
aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2 \
  --region us-east-1 --query Parameter.Value --output text



# Ubuntu 22.04，ami-0349abc8e982f4c8c
aws ssm get-parameter --name /aws/service/canonical/ubuntu/server/22.04/stable/current/arm64/hvm/ebs-gp2/ami-id \
  --region us-east-1 --query Parameter.Value --output text



## 不常用的。
# Red Hat Enterprise Linux 10
aws ec2 describe-images --owners 309956199498 --filters "Name=name,Values=RHEL-10*" "Name=architecture,Values=arm64" --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' --output text --region cn-north-1

# CentOS Stream 8
aws ec2 describe-images --owners 125523088429 --filters "Name=name,Values=CentOS Stream 9 aarch64*" "Name=architecture,Values=arm64" --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' --output text --region cn-north-1

# SUSE Linux Enterprise Server 15 SP6
aws ec2 describe-images --owners 013907871322 --filters "Name=name,Values=suse-sles-15-sp6*" "Name=architecture,Values=arm64" --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' --output text --region cn-north-1