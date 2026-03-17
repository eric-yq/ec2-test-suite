# Debian13 默认 AMI 自带的ENA 在 Graviton5 有点问题，安装最新的 ENA 驱动后就好了
# 现象：
# B 客户 使用 m9g.metal-48xl 作为 iperf server
# 使用两个 m9g.8xl 作为 iperf client，两个客户端同时发起流量，在 server 上只能看到约 15Gbps 左右网络带宽。
# 根据 TT，解决方法为更新 ENA 驱动到 2.16.1

# 新创建一个 m9g.2xlarge 更新驱动
apt update
apt install -y git dkms
git clone https://github.com/amzn/amzn-drivers.git
sudo mv amzn-drivers /usr/src/amzn-drivers-2.16.1
sudo vi /usr/src/amzn-drivers-2.16.1/dkms.conf
===========
PACKAGE_NAME="ena"
PACKAGE_VERSION="1.0.0"
CLEAN="make -C kernel/linux/ena clean"
MAKE="make -C kernel/linux/ena/ BUILD_KERNEL=${kernelver}"
BUILT_MODULE_NAME[0]="ena"
BUILT_MODULE_LOCATION="kernel/linux/ena"
DEST_MODULE_LOCATION[0]="/updates"
DEST_MODULE_NAME[0]="ena"
REMAKE_INITRD="yes"
AUTOINSTALL="yes"
===========

sudo dkms add -m amzn-drivers -v 2.16.1
# 更新头文件
apt install -y linux-headers-cloud-arm64
# 更新内核版本，更新的时候 dkms 会自动 build ena 驱动
apt upgrade -y
reboot
# 查看版本
uname -a
ethtool -i $(ip -o link show | awk -F': ' '!/lo/{print $2}' | head -1)

# 安装iperf
apt install -y iperf dstat
## 服务端
iperf -s -D
## 客户端
iperf -c 172.31.89.55 -P 16 -t 100 -i 10
iperf -c 172.31.89.55 -P 4 -t 100 -i 10

