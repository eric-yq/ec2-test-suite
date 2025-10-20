#!/bin/bash

# This script runs JMeter tests against the Spring Petclinic application.

# 实例类型
PN=$(cloud-init query ds.meta_data.instance_type)
# PN=$(ec2-metadata --quiet --instance-type)

# Install Java 25 Corretto, Git, and Python3-pip
yum install -y java-25-amazon-corretto java-25-amazon-corretto-devel git python3-pip
java -version
JDK_VERSION='corretto25'
pip3 install dool

# Clone the Spring Petclinic repository
git clone https://github.com/spring-projects/spring-petclinic.git
cd spring-petclinic
./mvnw package
nohup java -jar target/*.jar &

# Download and set up JMeter
cd /root/
wget https://downloads.apache.org/jmeter/binaries/apache-jmeter-5.6.3.tgz
tar -xzf apache-jmeter-5.6.3.tgz
sudo mv apache-jmeter-5.6.3 /opt/jmeter
sudo ln -s /opt/jmeter/bin/jmeter /usr/local/bin/jmeter
jmeter --version

# Run jmeter benchmark for Spring Petclinic
cd /root/spring-petclinic/src/test/jmeter
cp petclinic_test_plan.jmx petclinic_test_plan-modified.jmx

## 修改一些参数
sed -i "s/500/$\{__P(USERS,500)}/g"  petclinic_test_plan-modified.jmx


TIMESTAMP=$(date +%Y%m%d%H%M%S)
jmeter -n -t petclinic_test_plan.jmx -l results.jtl

jmeter -n -t petclinic_test_plan-modified.jmx \
  -JUSERS=123 \
  -JPETCLINIC_HOST=172.31.28.254 \
  -l results.jtl


# PARSE RESULTS AND GENERATE REPORT
REPORT_DIR=summary_report_${TIMESTAMP}
REPORT_ZIP=spring-petclinic_jmeter-summary-report_${JDK_VERSION}-${PN}-${TIMESTAMP}
jmeter -g results.jtl -o ./${REPORT_DIR}
tar czf ${REPORT_ZIP}.tar.gz ${REPORT_DIR}