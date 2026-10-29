#!/bin/bash

# Use user [ubuntu] of Ubuntu 22.04 on c6i.16xlarge
# refer: https://github.com/remote-android/redroid-doc/tree/master/android-builder-docker

# 1. Setup
# update and install packages
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y curl libxml2-utils docker.io docker-buildx git-lfs jq
sudo apt-get remove repo -y
sudo apt-get autoremove -y

# install 'repo'
mkdir -p ~/.bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/.bin/repo
chmod a+x ~/.bin/repo
echo 'export PATH=~/.bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# set git variables
git config --global user.email "yuanquan8261@163.com"
git config --global user.name "Quan Yuan"

# add current user to Docker group so we don't have to type 'sudo' to run Docker
sudo usermod -aG docker ubuntu # Set your username here
sudo systemctl enable docker
sudo systemctl restart docker
sudo systemctl status docker

# NOW YOU SHOULD LOGOUT AND LOGIN AGAIN FOR DOCKER TO RECOGNIZE OUR USER

# check if Docker is running
docker --version && docker ps -as
# Docker version 24.0.5, build 24.0.5-0ubuntu1~22.04.1
# CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES     SIZE

#2) Fetch and sync Android and Redroid codes
mkdir ~/redroid && cd ~/redroid

# check supported branch in https://github.com/remote-android/redroid-patches.git
repo init -u https://android.googlesource.com/platform/manifest --git-lfs --depth=1 -b android-13.0.0_r83

# add local manifests
git clone https://github.com/remote-android/local_manifests.git ~/redroid/.repo/local_manifests -b 13.0.0

# sync code | ~100GB of data | ~20 minutes on a fast CPU + connection
repo sync -c -j$(nproc)

# get latest Dockerfile from Redroid repository
wget https://raw.githubusercontent.com/remote-android/redroid-doc/master/android-builder-docker/Dockerfile

# check if 'Webview.apk' files were properly synced by 'git-lfs'. Each .apk should be at least ~80MB in size.
find ~/redroid/external/chromium-webview -type f -name "*.apk" -exec du -h {} +

#4) Apply Redroid patches, create builder and start it
# apply redroid patches
git clone https://github.com/remote-android/redroid-patches.git ~/redroid-patches
~/redroid-patches/apply-patch.sh ~/redroid

docker buildx create --use
docker buildx build --build-arg userid=$(id -u) --build-arg groupid=$(id -g) --build-arg username=$(id -un) -t redroid-builder --load .
docker run -it --privileged --rm --hostname redroid-builder --name redroid-builder -v ~/redroid:/src redroid-builder

#==================================================================
# Now we should be in the redroid-builder docker container
#5) Build Redroid： 
cd /src
. build/envsetup.sh
lunch redroid_arm64-userdebug
# redroid_x86_64-userdebug
# redroid_arm64-userdebug
# redroid_x86_64_only-userdebug (64 bit only, redroid 12+)
# redroid_arm64_only-userdebug (64 bit only, redroid 12+)

# start to build | + ~100GB of data | ~ 2 hours on a fast cpu
m -j$(nproc)

exit
#==================================================================

#6) Create Redroid image in HOST
cd ~/redroid/out/target/product/redroid_arm64
sudo mount system.img system -o ro
sudo mount vendor.img vendor -o ro

# set the target platform(s) with the '--platform flag' below. eg: --platform=linux/arm64,linux/amd64 ....
sudo tar --xattrs -c vendor -C system --exclude="./vendor" . | docker import --platform=linux/arm64 -c 'ENTRYPOINT ["/init", "qemu=1", "androidboot.hardware=redroid"]' - redroid
# execute only ↑ (without Step 3 Gapps) or ↓ (with Step 3 Gapps) | (OPTIONAL)
sudo tar --xattrs -c vendor -C system --exclude="./vendor" . | docker import --platform=linux/arm64 -c 'ENTRYPOINT ["/init", "qemu=1", "androidboot.hardware=redroid", "ro.setupwizard.mode=DISABLED"]' - redroid

sudo umount system vendor

# create rootfs only image for develop purpose (Optional)
tar --xattrs -c -C root . | docker import -c 'ENTRYPOINT ["/init", "androidboot.hardware=redroid"]' - redroid-dev

# inspect the created image to see if everything is ok
docker inspect redroid:latest | jq '.[0].Config.Entrypoint, .[0].Architecture'
[
  "/init",
  "qemu=1",
  "androidboot.hardware=redroid"
]
"arm64"

#7) Tag and push image to Docker Hub (optional)
AWS_REGION=$(ec2-metadata --quiet --region)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URL=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
# TAG the image.
docker images
# REPOSITORY        TAG               IMAGE ID       CREATED             SIZE
# redroid           latest            3789013c6ce3   15 minutes ago      1.67GB
# ......
docker tag redroid:latest $ECR_URL/redroid:13.0.0_arm64-latest

# Configure AWS CLI tool.
apt install -y awscli
aws configure
# ......

# Retrieve an authentication token and authenticate your Docker client to your registry. Use the AWS CLI:
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URL
# Push to ECR 
docker push $ECR_URL/redroid:13.0.0_arm64-latest

#================================================================
# In another Graviton instance, such as c7g.large(Ubuntu 20.04)
# Install docker
sudo su - root
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# Install kernel module
apt install -y linux-modules-extra-`uname -r`
modprobe binder_linux devices="binder,hwbinder,vndbinder"
modprobe ashmem_linux  
# check modules status
lsmod | grep -e ashmem_linux -e binder_linux

# Pull redroid-13 image from ECR repository
# Configure AWS CLI tool
apt install -y awscli
aws configure
# ......
AWS_REGION=$(ec2-metadata --quiet --region)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URL=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URL
docker pull $ECR_URL/redroid:13.0.0_arm64-latest
docker images

# Start a redroid container
docker run -itd --privileged --name Redroid13 -v ~/data:/data -p 5555:5555 $ECR_URL/redroid:13.0.0_arm64-latest

# Install ADB for remote connect
apt install -y adb
# Start ADB
adb connect localhost:5555


#================================================================
### Now switch to your MacOS ###
# install ADB and scrcpy tools.
brew install --cask android-platform-tools
brew install scrcpy
# connect to remote redroid container with 
ipaddr="public ip of ec2 instance"
port="5555"

# connect with ADB.(NOTE: DISCONNECT YOUR VPN CONNECTIONS FIRST)
adb connect ${ipaddr}:${port}

# logon to GUI 
scrcpy -s ${ipaddr}:${port} --no-audio --video-bit-rate=2M --max-size=1024 
