# Ubuntu 22.04, c6i.8xlarge

apt update
apt upgrade
apt install -y vim git python2 python3 python3-pip ninja-build clang-14
apt install -y pkg-config libglib2.0-dev 
ln -s /usr/bin/python2 /usr/bin/python
export PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/share/pkgconfig:/usr/lib/$(uname -p)-linux-gnu/pkgconfig

cd /opt
# 拉取编译工具
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH=/opt/depot_tools:$PATH

# 拉取v8代码
fetch --nohooks v8
cd v8
# # openrasp-v8 脚本中提供的下面这个 commit
# git checkout 6584de6be21c377b55f4f2b923388f1b6b0169cb 
# https://blog.csdn.net/tanjelly/article/details/134062127?spm=1001.2014.3001.5502 提供的
git checkout 8.6.395.17 
gclient sync -v

# 安装编译工具
cd /opt/v8
python build/linux/sysroot_scripts/install-sysroot.py --arch=arm64

# 构建配置
cd /opt/v8
mkdir -p out/arm64.release 
cat > out/arm64.release/args.gn <<EOF
is_debug = false
target_cpu = "arm64"
symbol_level = 0
is_component_build = false
treat_warnings_as_errors = false
use_custom_libcxx = false
libcxx_abi_unstable = false
v8_embedder_string = " <OpenRASP›"
v8_monolithic = true
v8_enable_i18n_support = false
v8_use_snapshot = true
v8_use_external_startup_data = false
v8_enable_shared_ro_heap = true
EOF
# 生成构建相关文件（过程中可能会提示 libcxx_abi_unstable 问题，直接忽略）
gn gen out/arm64.release

# 构建
/usr/bin/ninja -C out/arm64.release -j $(nproc) v8_monolith

## 查看文件
ll /opt/v8/out/arm64.release/obj/*.a
# -rw-r--r-- 1 root root    20892 Feb 11 11:03 libv8_libbase.a
# -rw-r--r-- 1 root root    18732 Feb 11 11:03 libv8_libplatform.a
# -rw-r--r-- 1 root root 38084466 Feb 11 11:05 libv8_monolith.a


## 下载 libv8_monolith.a 
## ......
















