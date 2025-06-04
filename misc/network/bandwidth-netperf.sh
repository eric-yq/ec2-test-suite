# Amazon Linux 2

## 安装 netperf
wget https://codeload.github.com/HewlettPackard/netperf/tar.gz/netperf-2.7.0
tar -xzvf netperf-2.7.0
yum install -y gcc sysstat python3-pip
pip3 install dool
cd ./netperf-netperf-2.7.0
if [ "$(uname -m)" = "aarch64" ]; then
    ./configure --build=aarch64-unknown-linux-gnu
else
    ./configure
fi
make
make install

## 服务端启动
M=8
for i in $(seq 1 $M)
do
    let PORT=11999+$i # 端口从12000开始
    netserver -p $PORT -L 0.0.0.0 &
done

## 客户端，执行带宽测试
SERVER_IP="172.31.73.14"
DURATION=60
MESSAGE_SIZE=65536
SEND_BUFFER=1048576
RECV_BUFFER=1048576
N=8 ###启动8个netperf进程
for i in $(seq 1 $N); do
  let PORT=11999+$i
  netperf -H $SERVER_IP -p $PORT -l $DURATION -t TCP_STREAM \
    -- -m $MESSAGE_SIZE -s $SEND_BUFFER -S $RECV_BUFFER &
  sleep 0.5
done



## 监控
dool --cpu --sys --net --net-packets -N eth0 --proc-count --time --bits 5 14