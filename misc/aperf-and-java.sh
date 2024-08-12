yum install -y java-17-amazon-corretto htop dstat
## 升级内核
amazon-linux-extras install kernel-5.15 -y
reboot

wget https://github.com/renaissance-benchmarks/renaissance/releases/download/v0.14.2/renaissance-gpl-0.14.2.jar
java -jar renaissance-gpl-0.14.2.jar -r 8 finagle-http




## 优化x
java -XX:+UseZGC -XX:-TieredCompilation -XX:+UseTransparentHugePages \
     -jar renaissance-gpl-0.14.2.jar -r 8 finagle-http
