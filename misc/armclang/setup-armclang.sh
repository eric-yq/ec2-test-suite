# EC2: c7g.xlarge(EBS: gp3 80G)
# OS:  Amazon Linux 2023, 
sudo su - root
yum groupinstall -y "Development Tools"
yum -y install environment-modules python3 glibc-devel
mount -o remount,size=20G /tmp/

# 方式1. 自动安装
bash <(curl -L https://developer.arm.com/-/cdn-downloads/permalink/Arm-Compiler-for-Linux/Package/install.sh)

# 方式2. 手动安装
wget https://developer.arm.com/-/cdn-downloads/permalink/Arm-Compiler-for-Linux/Version_24.10.1/arm-compiler-for-linux_24.10.1_AmazonLinux-2023_aarch64.tar
tar xf arm-compiler-for-linux_24.10.1_AmazonLinux-2023_aarch64.tar
cd arm-compiler-for-linux_24.10.1_AmazonLinux-2023
./arm-compiler-for-linux_24.10.1_AmazonLinux-2023.sh --accept
## 等待安装完成.....

echo "source /usr/share/Modules/init/bash" >> ~/.bashrc
echo "module use /opt/arm/modulefiles" >> ~/.bashrc
source ~/.bashrc
module avail
module load acfl/24.10.1
module load armpl/24.10.1
module load gnu/14.2.0
module list
armclang++ --version
g++ --version

