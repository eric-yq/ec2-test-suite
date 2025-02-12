# c7g.xlarge, Amazon Linux 2023

# 使用另一个修改库 https://github.com/tanjelly/openrasp-v8

# 编译 openrasp-v8 基础库
yum groupinstall -y "Development Tools"
yum install -y java-11-amazon-corretto java-11-amazon-corretto-devel java-11-amazon-corretto-headless
yum install -y cmake 

cd /root/
VER=3.9.8
wget https://dlcdn.apache.org/maven/maven-3/${VER}/binaries/apache-maven-${VER}-bin.tar.gz
tar zxf apache-maven-${VER}-bin.tar.gz -C /usr/ --strip-components 1
mvn -v

git clone https://github.com/tanjelly/openrasp-v8.git
cd openrasp-v8/
git submodule update --init
mkdir -p build64 && cd build64
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DENABLE_LANGUAGES=java ..
make -j

## nm -D java/libopenrasp_v8_java.so | grep _ZN2v88platform18NewDefaultPlatformE
mkdir -p ../java/src/main/resources/natives/linux_arm64 && cp java/libopenrasp_v8_java.so $_

cd ../java
mvn install

# 编译 OpenRASP, 参考 https://rasp.baidu.com/doc/hacking/compile/java.html#java-v8
cd /root/
git clone https://github.com/baidu/openrasp.git
cd openrasp
cp -r /root/openrasp-v8/ .
cd /root/openrasp/agent/java
mvn versions:use-latest-releases -Dincludes=com.baidu.openrasp:sqlparser
mvn clean package
