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
# 设置 HBASE 的 主机名，单机：
HBASE_NODES="node1"

# 设置 HBASE 的 IP 地址，集群：
HBASE_NODES="node1,node2,node3"
#######################################

rm -rf conf/hbase-site.xml
cp -f  conf/hbase-site.xml.template conf/hbase-site.xml
sed -i "s/xxxxxx/${HBASE_NODES}/g" conf/hbase-site.xml
diff conf/hbase-site.xml*

# 将 node1/2/3 和对应的 IP 地址，添加到 /etc/hosts 文件中
IPADDR_NODE1="172.31.41.204"
IPADDR_NODE2="172.31.46.82"
IPADDR_NODE3="172.31.43.95"

sudo cat >> /etc/hosts << EOF
$IPADDR_NODE1 node1
$IPADDR_NODE2 node2
$IPADDR_NODE3 node3
EOF

screen -R ttt -L

### 单机模式下，采用默认配置即可
# 快速测试
./fast_test

# 完整测试
./full_test

### 3 节点集群模式下，可以将线程数调大
./fast_test -p ahbench.test.threads=500 
./full_test -p ahbench.test.threads=500 

# 如果要重新执行测试用例，可以跳过加载数据的阶段
./fast_test -p ahbench.test.threads=500 -p ahbench.default_suite.runtime=1800 --skipload
./full_test -p ahbench.test.threads=500 -p ahbench.default_suite.runtime=1800 --skipload