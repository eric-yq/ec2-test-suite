pt install -y  g++-aarch64-linux-gnu gcc-aarch64-linux-gnu libc6-dev-arm64-cross libstdc++-10-dev-arm64-cross 
export CC=aarch64-linux-gnu-gcc
export CXX=aarch64-linux-gnu-g++
export CPP=aarch64-linux-gnu-cpp
export AR=aarch64-linux-gnu-ar
export AS=aarch64-linux-gnu-as
export LD=aarch64-linux-gnu-ld
export RANLIB=aarch64-linux-gnu-ranlib
export STRIP=aarch64-linux-gnu-strip
export CPPFLAGS="-I/usr/aarch64-linux-gnu/include"
export LDFLAGS="-L/usr/aarch64-linux-gnu/lib"

## 测试目的：xapian-core-1.4.18.tar.xz
wget https://oligarchy.co.uk/xapian/1.4.18/xapian-core-1.4.18.tar.xz
tar xf xapian-core-1.4.18.tar.xz
cd xapian-core-1.4.18
./configure
####
# 这里就过不去了，一堆错误
####
apt install zlib1g-dev
./configure --host=aarch64-linux-gnu --prefix=/usr/local/aarch64-linux-gnu 
make -j 2  && \
make install  && \


## 