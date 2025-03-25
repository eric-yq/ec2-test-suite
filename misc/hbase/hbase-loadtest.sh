#!/bin/bash 

# 需要预装好 JDK(省略)

cd /root/
https://hbaseuepublic.oss-cn-beijing.aliyuncs.com/AHBench-v1.0.5.tar.gz
tar zxf AHBench-v1.0.5.tar.gz

cd AHBench

# 生成配置文件
cat > conf/ahbench-env.properties  << EOL
JAVA_HOME=/usr/lib/jvm/jre
HBASE_VERSION=2
EOL
cat > conf/hbase-site.xml.template << EOL
<configuration>
    <property>
         <name>hbase.zookeeper.quorum</name>
         <value>xxxxxx</value>
     </property> 
</configuration>
EOL

#######################################
# 设置 HBASE 的 IP 地址
HBASE_IPADDR="172.31.9.220"
#######################################
rm -rf conf/hbase-site.xml
cp -f  conf/hbase-site.xml.template conf/hbase-site.xml
sed -i "s/xxxxxx/${HBASE_IPADDR}/g" conf/hbase-site.xml
diff conf/hbase-site.xml*

screen -R ttt -L

# 快速测试
./fast_test

# 完整测试
./full_test