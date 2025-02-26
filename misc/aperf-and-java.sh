# amazon linux 2

yum install -y java-17-amazon-corretto htop dstat

## 升级内核
amazon-linux-extras install kernel-5.15 -y
reboot

## 下载测试工具
wget https://github.com/renaissance-benchmarks/renaissance/releases/download/v0.14.2/renaissance-gpl-0.14.2.jar
java -jar renaissance-gpl-0.14.2.jar -r 8 finagle-http

## 安装 aperf
VERSION="v0.1.13-alpha"
wget https://github.com/aws/aperf/releases/download/$VERSION/aperf-$VERSION-$(arch).tar.gz -O  aperf-$VERSION.tar.gz 
tar zxf aperf-$VERSION.tar.gz --strip-components 1 -C /usr/local/bin/
aperf -V

#enable PMU access
echo 0 | sudo tee /proc/sys/kernel/perf_event_paranoid
#APerf has to open more than the default limit of files.
ulimit -n 65536
#usually aperf would be run in another terminal. 
#For illustration purposes it is send to the background here
aperf record --run-name finagle_$(arch) --period 60 &
#With 64 CPUs it takes APerf a little less than 15s to report readiness for data collection.
sleep 50
java -jar renaissance-gpl-0.14.2.jar -r 8 finagle-http


## 优化 
aperf record --run-name finagle_$(arch)_optimization --period 60
sleep 50
java -XX:+UseParallelGC -XX:-TieredCompilation -XX:+UseTransparentHugePages \
     -jar renaissance-gpl-0.14.2.jar -r 8 finagle-http


## 无密码登录
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa && cat ~/.ssh/id_rsa.pub
chmod 0600 ~/.ssh/authorized_keys
vi ~/.ssh/authorized_keys
...


## 对比报告
# [root@ip-172-31-3-29 ~]# ll
# total 422616
# drwxr-xr-x 5 root root        93 Aug  9 10:41 aperf_report_finagle_aarch64_finagle_x86_64
# -rw-r--r-- 1 root root   4592449 Aug  9 10:41 aperf_report_finagle_aarch64_finagle_x86_64.tar.gz
# -rw-r--r-- 1 root root   6497901 Jul 31 22:08 aperf-v0.1.12-alpha.tar.gz
# drwxr-xr-x 2 root root      4096 Aug  9 10:27 finagle_aarch64
# drwxr-xr-x 2 root root      4096 Aug  9 10:30 finagle_aarch64_optimization
# -rw-r--r-- 1 root root   1130637 Aug  9 10:32 finagle_aarch64_optimization.tar.gz
# -rw-r--r-- 1 root root   1161096 Aug  9 10:29 finagle_aarch64.tar.gz
# drwxr-xr-x 2 root root      4096 Aug  9 10:40 finagle_x86_64
# drwxr-xr-x 2 root root      4096 Aug  9 10:40 finagle_x86_64_optimization
# -rw-r--r-- 1 root root   1154698 Aug  9 10:40 finagle_x86_64_optimization.tar.gz
# -rw-r--r-- 1 root root   1179004 Aug  9 10:40 finagle_x86_64.tar.gz
# -rw-r--r-- 1 root root 417011711 Feb 27  2023 renaissance-gpl-0.14.2.jar
aperf report --run finagle_aarch64 --run finagle_x86_64
aperf report --run finagle_aarch64_optimization --run finagle_x86_64_optimization


aperf report --run finagle_aarch64 --run finagle_x86_64 \
             --run finagle_aarch64_optimization --run finagle_x86_64_optimization

cp aperf_report_*.tar.gz /home/ec2-user/












