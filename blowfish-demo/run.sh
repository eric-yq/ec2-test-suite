#!/bin/bash
#
## 执行客户demo程序
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2> /dev/null)
instance_type="$(curl -H "X-aws-ec2-metadata-token: ${TOKEN}" http://169.254.169.254/latest/meta-data/instance-type 2> /dev/null)"

N=$1

for i in $(seq 1 $N)
do
    echo "Start to test =$i..."
    for j in $(seq 1 $i)
    do
        java -jar unitTest-1.0-SNAPSHOT.jar "Blowfish" > result-$instance_type-$i-$j.log &
    done
    wait
done
grep "总耗时" *.log > result-summary-$instance_type.txt  && rm -rf *.log
cat result-summary-$instance_type.txt