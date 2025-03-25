
## 安装docker
yum install -y docker python3-pip htop iotop
pip3 install dool
systemctl start docker

## 安装Docker compose
ARCH=$(arch)
curl -SL https://github.com/docker/compose/releases/download/v2.12.2/docker-compose-linux-${ARCH} -o /usr/bin/docker-compose
chmod +x /usr/bin/docker-compose




##############################################################################################################
# Install Porcess Watch, on Ubuntu 22.04
# https://learn.arm.com/learning-paths/servers-and-cloud-computing/processwatch/
sudo apt-get update
sudo apt-get install libelf-dev cmake clang llvm llvm-dev -y
git clone --recursive https://github.com/intel/processwatch.git
cd processwatch
./build.sh -b
sudo setcap CAP_PERFMON,CAP_BPF=+ep ./processwatch
sudo sysctl -w kernel.perf_event_paranoid=-1
sudo sysctl kernel.unprivileged_bpf_disabled=0
sudo ./processwatch -h
sudo ./processwatch
sudo ./processwatch -l
sudo ./processwatch -l -m

cat << EOF > workload.c
#include <stdint.h>
#define LEN 1024
uint64_t a[LEN];
uint64_t b[LEN];
uint64_t c[LEN];
void doLoop() {
  for (int i = 0; i < LEN; i++)
    c[i] = a[i] + b[i];
}
void main() {
  while (1)
    doLoop();
}
EOF
## 不同编译
aarch64-linux-gnu-gcc workload.c -o workload_none -O0
aarch64-linux-gnu-gcc workload.c -o workload_o3   -O3
aarch64-linux-gnu-gcc workload.c -o workload_neon -O2 -ftree-vectorize -march=armv8.4-a
aarch64-linux-gnu-gcc workload.c -o workload_sve  -O2 -ftree-vectorize -march=armv8.4-a+sve
aarch64-linux-gnu-gcc	 workload.c -o workload_mcpu -O3 -mcpu=neoverse-v1
./workload_mcpu && ./workload_neon && ./workload_sve && ./workload_mcpu
## 查看监控
sudo ./processwatch  -f HasNEON -f HasSVEorSME -i 5
# PID      NAME             NEON     SVEorSME %TOTAL   TOTAL   
# ALL      ALL              20.98    12.68    100.00   254385  
# 3824     workload_none    0.00     0.00     18.96    48219   
# 3997     workload_neon    32.19    0.00     18.38    46744   
# 4059     workload_mcpu    32.15    0.00     18.15    46164   
# 4074     workload_o3      32.28    0.00     15.94    40538   
# 4017     workload_sve     0.00     96.64    13.12    33388   
# 4046     workload_mcpu_n  32.37    0.00     12.51    31817   
# 4077     processwatch     1.15     0.00     2.95     7500  


##############################################################################################################
# Install sysbench on Amazon Linux 2023
yum -y install gcc make automake libtool pkgconfig libaio-devel mariadb105-devel
wget https://github.com/akopytov/sysbench/archive/refs/tags/1.0.20.tar.gz
tar zxf 1.0.20.tar.gz &&  cd sysbench-1.0.20/
./autogen.sh
./configure 
make -j
make install
which sysbench

##############################################################################################################
# Perform benchmark with ACCP（单线程）
if [[ $(arch) == "x86_64" ]]; then
    ARCH="x86_64"
else
    ARCH="aarch_64"
fi
wget https://github.com/corretto/amazon-corretto-crypto-provider/releases/download/2.4.1/AmazonCorrettoCryptoProvider-2.4.1-linux-$ARCH.jar
git clone https://github.com/corretto/amazon-corretto-crypto-provider.git
yum install -y clang-*
cd amazon-corretto-crypto-provider/benchmarks
./gradlew -PaccpLocalJar="/root/AmazonCorrettoCryptoProvider-2.4.1-linux-$ARCH.jar" lib:jmh

##############################################################################################################
# 编译 tcprstat，Ubuntu 22.04
apt install -y build-* yacc flex git autoconf
git clone https://github.com/Lowercases/tcprstat.git
cd tcprstat
autoreconf -fvi
./configure --build=aarch64-unknown-linux-gnu
sed -i.bak "140a #include <sys\/ioctl.h>\n#include <linux\/sockios.h>\n" libpcap/libpcap-1.1.1/pcap-linux.c
diff libpcap/libpcap-1.1.1/pcap-linux.c*
cd libpcap && make
cd .. && make CFLAGS="-fsigned-char" && make install
tcprstat --version
#验证一下
apt install -y sysbench mysql-server
system status mysql


