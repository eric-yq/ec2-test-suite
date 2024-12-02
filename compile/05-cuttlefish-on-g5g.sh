# g5g.metal, Ubuntu 22.04（Graviton2 CPU(64vCPU) + 2*T4 GPU）
# 下面命令有返回结果
find /dev/ -name kvm

# 安装 GPU 驱动
sudo su - root
wget https://gist.githubusercontent.com/bilalmughal/cb89936bc947fa727a8ec66e3ddf768a/raw/7f7f2152f88dbe8fd02b4b88a3b0a4d0d7264644/ffmpeg_install_gpu.sh
bash ffmpeg_install_gpu.sh

# 编译/安装
git clone https://github.com/google/android-cuttlefish
cd android-cuttlefish
./tools/buildutils/build_packages.sh
ll *.deb
# -rw-r--r-- 1 root root 2492358 May 24 10:43 cuttlefish-base_0.9.29_arm64.deb
# -rw-r--r-- 1 root root    4562 May 24 10:43 cuttlefish-common_0.9.29_arm64.deb
# -rw-r--r-- 1 root root    7238 May 24 10:43 cuttlefish-integration_0.9.29_arm64.deb
# -rw-r--r-- 1 root root    8760 May 24 10:44 cuttlefish-orchestration_0.9.29_arm64.deb
# -rw-r--r-- 1 root root 6167342 May 24 10:45 cuttlefish-user_0.9.29_arm64.deb
sudo dpkg -i ./cuttlefish-base_*_*64.deb || sudo apt-get install -f
sudo dpkg -i ./cuttlefish-user_*_*64.deb || sudo apt-get install -f
sudo usermod -aG kvm,cvdnetwork,render $USER
sudo reboot

## 参考  https://android.googlesource.com/device/google/cuttlefish/ 第 3～8 步骤
# For ARM, use ：
# branch: aosp-main-throttled 
# device target: aosp_cf_arm64_only_phone-trunk_staging-userdebug
# 下载 aosp_cf_arm64_only_phone-img-*.zip 和 cvd-host_package.tar.gz
## 上传到 g5g.metal 实例。
mkdir cf && cd cf
tar zxf ../cvd-host_package.tar.gz
unzip ../aosp_cf_arm64_only_phone-img-*.zip

## 修改并行连接数, 例如 32
sed -i.bak "s/#num_cvd_accounts=10/num_cvd_accounts=32/g" /etc/default/cuttlefish-host-resources
systemctl restart cuttlefish-host-resources

## 启动
HOME=$PWD ./bin/launch_cvd --daemon --start_webrtc=true --gpu_mode=gfxstream \
  --num_instances=16

## 检查状态
HOME=$PWD ./bin/cvd_status

## 停止
HOME=$PWD ./bin/stop_cvd

## g5g.metal 安全组中添加入站规则：
# TCP - 8443,
# TCP - 15500 - 15599
# UDP - 15500 - 15599

