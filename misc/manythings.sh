# Install sysbench on Amazon Linux 2023
yum -y install gcc make automake libtool pkgconfig libaio-devel mariadb105-devel
wget https://github.com/akopytov/sysbench/archive/refs/tags/1.0.20.tar.gz
tar zxf 1.0.20.tar.gz &&  cd sysbench-1.0.20/
./autogen.sh
./configure 
make -j
make install
which sysbench


# Perform benchmark with ACCP


