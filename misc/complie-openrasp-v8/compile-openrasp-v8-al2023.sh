### 环境: c7g.xlarge, Amazon Linux 2023

yum groupinstall -y "Development Tools"
yum install -y java-11-amazon-corretto java-11-amazon-corretto-devel java-11-amazon-corretto-headless
yum install -y cmake openssl-devel

cd /root/
VER=3.9.8
wget https://dlcdn.apache.org/maven/maven-3/${VER}/binaries/apache-maven-${VER}-bin.tar.gz
tar zxf apache-maven-${VER}-bin.tar.gz -C /usr/ --strip-components 1
mvn -v

# 下载代码并编译
git clone https://github.com/baidu-security/openrasp-v8.git
cd openrasp-v8/
git submodule update --init
mkdir -p build64 && cd build64
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DENABLE_LANGUAGES=java ..
make -j

### 报错 ### 

## 下面这些文件是编译脚本自动下载的，都是 x86 架构，需要对应的 aarch64 架构
# ls /root/openrasp-v8/prebuilts/linux/lib64/
# libc++.a  libc++abi.a  libcrypto.a  libcurl.a  libssl.a  libv8_monolith.a  libz.a

### 逐个处理 ###
# 1
cd /root/
yum install -y zlib-static 
#  find  / -name libz.a
# /usr/lib64/libz.a

# 2
cd /root/
wget https://github.com/curl/curl/archive/refs/tags/curl-8_5_0.tar.gz
tar zxf curl-8_5_0.tar.gz
cd curl-curl-8_5_0/
./buildconf 
./configure --prefix=/usr/local/curl-8.5.0 --with-ssl
make CFLAGS="-fPIC" -j
#  find  / -name libcurl.a
# /root/curl-curl-8_5_0/lib/.libs/libcurl.a

# 3
cd /root/
wget https://github.com/openssl/openssl/archive/refs/tags/openssl-3.0.8.tar.gz
tar zxf openssl-3.0.8.tar.gz
cd openssl-openssl-3.0.8/
./config no-shared --openssldir=/usr/local/ssl-3.0.8
make -j
#  find  / -name libcrypto.a
# /root/openssl-openssl-3.0.8/libcrypto.a
#  find  / -name libssl.a
# /root/openssl-openssl-3.0.8/libssl.a

# 4. 先完成 compile-libv8-ubuntu2204.sh 
# 然后将 libv8_monolith.a 上传到 /home/ec2-user/

# 5
cd /root/
wget https://github.com/llvm/llvm-project/releases/download/llvmorg-19.1.5/clang+llvm-19.1.5-aarch64-linux-gnu.tar.xz
tar xf clang+llvm-19.1.5-aarch64-linux-gnu.tar.xz
#  find / -name libc++.a
# /root/clang+llvm-19.1.5-aarch64-linux-gnu/lib/aarch64-unknown-linux-gnu/libc++.a
#  find / -name libc++abi.a
# /root/clang+llvm-19.1.5-aarch64-linux-gnu/lib/aarch64-unknown-linux-gnu/libc++abi.a


### 替换 lib*.a 文件 ### 
cd /root/openrasp-v8/prebuilts/linux/
mv lib64 lib64.bak
mkdir lib64
cp /usr/lib64/libz.a \
   /root/curl-curl-8_5_0/lib/.libs/libcurl.a \
   /root/openssl-openssl-3.0.8/libcrypto.a \
   /root/openssl-openssl-3.0.8/libssl.a \
   /root/clang+llvm-19.1.5-aarch64-linux-gnu/lib/aarch64-unknown-linux-gnu/libc++.a \
   /root/clang+llvm-19.1.5-aarch64-linux-gnu/lib/aarch64-unknown-linux-gnu/libc++abi.a \
   /root/openrasp-v8/prebuilts/linux/lib64/

cp /home/ec2-user/libv8_monolith.a /root/openrasp-v8/prebuilts/linux/lib64/
   
# ll /root/openrasp-v8/prebuilts/linux/lib64/
# total 187036
# -rw-r--r--. 1 root root   2444418 Feb 10 08:41 libc++.a
# -rw-r--r--. 1 root root    732926 Feb 10 08:41 libc++abi.a
# -rw-r--r--. 1 root root   9381388 Feb 10 08:41 libcrypto.a
# -rw-r--r--. 1 root root   1876456 Feb 10 08:50 libcurl.a
# -rw-r--r--. 1 root root   1267220 Feb 10 08:41 libssl.a
# -rw-r--r--. 1 root root 175557396 Feb 10 08:41 libv8_monolith.a
# -rw-r--r--. 1 root root    251086 Feb 10 08:41 libz.a

### 重新编译 ### 
cd /root/openrasp-v8/build64
make clean
make -j
# ......
# [100%] Linking CXX shared library libopenrasp_v8_java.so
# [100%] Built target openrasp_v8_java
# [root@ip-172-31-44-169 build64]# cd ..
# [root@ip-172-31-44-169 openrasp-v8]# find . -name *.so
# ./build64/java/libopenrasp_v8_java.so
nm -D java/libopenrasp_v8_java.so | grep _ZN2v88platform18NewDefaultPlatformE

mkdir -p ../java/src/main/resources/natives/linux_arm64 && cp java/libopenrasp_v8_java.so $_

## 打包
cd ../java
mvn clean
mvn install

mvn clean install -DskipTests


