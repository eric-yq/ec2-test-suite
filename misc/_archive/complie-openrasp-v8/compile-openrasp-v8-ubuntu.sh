## 安装依赖库。
apt install gcc g++ git libc++-dev libc++abi-dev libssl-dev libcurl4-openssl-dev zlib1g-dev 
apt install ruby-rubygems cmake openjdk-11-jdk
gem install libv8-node -v 23.6.1.0
cd /usr/lib/aarch64-linux-gnu/
cp /usr/lib/aarch64-linux-gnu/libv8_monolith.a .
cp /usr/lib/llvm-14/lib/libc++abi.a .
cp /usr/lib/llvm-14/lib/libc++.a .
ls libc++.a  libc++abi.a  libcrypto.a libssl.a libcurl.a libv8_monolith.a  libz.a

## 编译
cd /root/
git clone https://github.com/baidu-security/openrasp-v8.git
mkdir -p openrasp-v8/build64 && cd openrasp-v8/build64
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DENABLE_LANGUAGES=java ..
make

### 替换 lib*.a 文件 ### 
cd /root/openrasp-v8/prebuilts/linux/
mv lib64 lib64.bak
mkdir lib64

cd /usr/lib/aarch64-linux-gnu/
cp libc++.a libc++abi.a libcrypto.a libssl.a libcurl.a libv8_monolith.a libz.a \
   /root/openrasp-v8/prebuilts/linux/lib64/
ls -l /root/openrasp-v8/prebuilts/linux/lib64

## 重新编译
cd /root/openrasp-v8/build64/
make clean
make

