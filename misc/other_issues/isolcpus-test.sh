# amazon linux 2023 

sudo su - root

vi /etc/default/grub 
# add isolcpus=1,2,3 at the end of GRUB_CMDLINE_LINUX_DEFAULT
# GRUB_CMDLINE_LINUX_DEFAULT="console=tty0 console=ttyS0,115200n8 nvme_core.io_timeout=4294967295 rd.emergency=poweroff rd.shell=0 selinux=1 security=selinux quiet isolcpus=1,2,3"
grub2-mkconfig -o /boot/grub2/grub.cfg
reboot

cat /proc/cmdline

## Run stress-ng in all vcpu with load 75%, but it will only run in vcpu 04567
stress-ng --cpu $(nproc) --cpu-load 75 &

## Build SuperPI 
yum install -y git gcc gcc-c++ stress-ng htop
git clone https://github.com/Fibonacci43/SuperPI.git
cd SuperPI
gcc -O -funroll-loops -fomit-frame-pointer pi_fftcs.c fftsg_h.c -lm -o pi_css5

## 将SuperPI 运行程序绑定在 vCPU 2.
taskset -c 2 ./pi_css5 123456789