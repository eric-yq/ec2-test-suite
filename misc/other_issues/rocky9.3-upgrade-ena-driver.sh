

## 升级系统, kernel 会被一同升级；应该也可以不执行这个。
dnf update -y
reboot

## 重启后查看版本信息。
uname -a
modinfo ena
ethtool -i eth0
depmod -n | grep ena.ko

## 编译
dnf install -y kernel-devel kernel-headers gcc make git
git clone https://github.com/amzn/amzn-drivers
cd amzn-drivers/kernel/linux/ena
make
ls -l ena.ko

## 备份老的驱动文件
mkdir -p /root/ena_bak
mv /lib/modules/$(uname -r)/kernel/drivers/net/ethernet/amazon/ena/* /root/ena_bak 
ls -l /root/ena_bak

## 新编译的 ena.ko 复制到下面目录
cp ena.ko /lib/modules/$(uname -r)/kernel/drivers/net/ethernet/amazon/ena/ena.ko.xz
depmod
modinfo ena

## 更新initramfs
dracut -f

## 重启
reboot

## 查看版本
uname -a
# Linux ip-172-31-18-59.us-east-2.compute.internal 5.14.0-427.24.1.el9_4.x86_64 #1 SMP PREEMPT_DYNAMIC Mon Jul 8 17:47:19 UTC 2024 x86_64 x86_64 x86_64 GNU/Linux

modinfo ena
# filename:       /lib/modules/5.14.0-427.24.1.el9_4.x86_64/kernel/drivers/net/ethernet/amazon/ena/ena.ko.xz
# version:        2.12.3g

ethtool -i eth0
# driver: ena
# version: 2.12.3g







##### 安装 dkms ????
yum install -y https://archives.fedoraproject.org/pub/archive/epel/9.3/Everything/$(arch)/Packages/e/epel-release-9-7.el9.noarch.rpm 
yum install -y dkms
VER=$(grep ^VERSION /usr/src/kernels/$(uname -r)/Makefile | cut -d' ' -f3)
# VERSION = 5

https://repost.aws/zh-Hans/knowledge-center/install-ena-driver-rhel-ec2


