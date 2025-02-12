
apt install gcc g++ git libc++-dev libc++abi-dev libssl-dev libcurl4-openssl-dev zlib1g-dev 

apt install ruby-rubygems
gem install libv8-node -v 23.6.1.0

cd /usr/lib/aarch64-linux-gnu/
cp /usr/lib/aarch64-linux-gnu/libv8_monolith.a .
cp /usr/lib/llvm-18/lib/libc++abi.a .
cp /usr/lib/llvm-14/lib/libc++.a .

ls libc++.a  libc++abi.a  libcrypto.a libssl.a libcurl.a libv8_monolith.a  libz.a



ls libc++.a  libc++abi.a  libcrypto.a    libssl.a  libcurl.a libv8_monolith.a  libz.a
   26  apt install ruby-rubygems
   27  gem install libv8-node -v 23.6.1.0
   28  find / -name "libv8_monolith.a"
   29  
   30  ls libc++.a  libc++abi.a  libcrypto.a    libssl.a  libcurl.a libv8_monolith.a  libz.a
   31  find / -name "libc++abi.a"
   32  cp /usr/lib/llvm-18/lib/libc++abi.a .
   33  ls libc++.a  libc++abi.a  libcrypto.a    libssl.a  libcurl.a libv8_monolith.a  libz.a
   34  apt install git
   35  cd
   36  git clone https://github.com/baidu-security/openrasp-v8.git
   37  cd openrasp-v8/
   38  ll
   39  cd ..
   40  mkdir -p openrasp-v8/build64 && cd openrasp-v8/build64
   41  cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DENABLE_LANGUAGES=java ..
   42  apt isntall cmake
   43  apt install cmake
   44  java -version
   45  apt install openjdk-8-jre-headless
   46  java -version
   47  cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DENABLE_LANGUAGES=java ..
   48  apt search openjdk*
   49  apt install openjdk-8-jdk
   50  cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DENABLE_LANGUAGES=java ..
   51  make -j
   52  ll
   53  cd /usr/lib/aarch64-linux-gnu/
   54  ll
   55  cd 
   56  cd openrasp-v8/n


cd /usr/lib/aarch64-linux-gnu/
cp libc++.a  libc++abi.a  libcrypto.a    libssl.a  libcurl.a libv8_monolith.a  libz.a \
 /root/openrasp-v8/prebuilts/linux/lib64
cd /root/openrasp-v8/prebuilts/linux/lib64
