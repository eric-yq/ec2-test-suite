# 参考步骤：c7g.xlarge, Amazon Linux 2023
# 软件版本：baidu/openrasp v1.3.6 + tanjelly/openrasp-v8 v2

# 使用另一个修改库 https://github.com/tanjelly/openrasp-v8
# 编译 openrasp-v8 基础库
yum groupinstall -y "Development Tools"
yum install -y java-11-amazon-corretto java-11-amazon-corretto-devel java-11-amazon-corretto-headless
yum install -y cmake 

cd /root/
VER=3.9.11
wget https://dlcdn.apache.org/maven/maven-3/${VER}/binaries/apache-maven-${VER}-bin.tar.gz
tar zxf apache-maven-${VER}-bin.tar.gz -C /usr/ --strip-components 1
mvn -v

git clone https://github.com/tanjelly/openrasp-v8.git
cd openrasp-v8/
mkdir -p build64 && cd build64
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DENABLE_LANGUAGES=java ..
make -j

## nm -D java/libopenrasp_v8_java.so | grep _ZN2v88platform18NewDefaultPlatformE
mkdir -p ../java/src/main/resources/natives/linux_arm64 && cp java/libopenrasp_v8_java.so $_

# x86
# mkdir -p ../java/src/main/resources/natives/linux_x64 && cp java/libopenrasp_v8_java.so $_

cd ../java
mvn install

# 编译 OpenRASP, 参考 https://rasp.baidu.com/doc/hacking/compile/java.html#java-v8
######## Kenny Lai 提供的参考：######## 
cd /root
git clone https://github.com/baidu/openrasp.git
cd openrasp
git checkout v1.3.6
git submodule update --init
cd agent/java

vi pom.xml 
# comment 掉 <module>../../openrasp-v8/java</module>

vi /root/openrasp/agent/java/boot/src/main/java/com/baidu/openrasp/Agent.java
# go to line 20, add // before import sun.management.FileSystem;

mvn versions:use-latest-releases -Dincludes=com.baidu.openrasp:sqlparser
mvn clean package

cp /root/openrasp/agent/java/engine/target/rasp-engine.jar .
cp /root/openrasp/agent/java/boot/target/rasp.jar .

java --add-opens=java.base/jdk.internal.ref=ALL-UNNAMED --add-opens=java.base/jdk.internal.loader=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED -javaagent:rasp.jar -jar demo-server.jar
