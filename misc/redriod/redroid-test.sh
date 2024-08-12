# 测试 1：容器启动不设置 --cpuset-cpus
## 启动容器
docker run -itd --rm --privileged \
  -v ~/redroid11_tiktok-33.7.2:/data -p 5001:5555 redroid/redroid:11.0.0-latest \
  androidboot.redroid_width=720 \
  androidboot.redroid_height=1280 \
  androidboot.redroid_dpi=320
## Linux perf 监控命令： 
perf record -ag -F99 -o perf-test1.data sleep 60
## 客户端连接
adb connect 43.206.94.215:5001
scrcpy -s 43.206.94.215:5001 --no-audio --video-bit-rate=2M

# 测试 2：容器启动 设置  --cpuset-cpus="0"
## 启动容器
docker run -itd --rm --privileged --cpuset-cpus="0" \
  -v ~/redroid11_tiktok-33.7.2:/data -p 5002:5555 redroid/redroid:11.0.0-latest \
  androidboot.redroid_width=720 \
  androidboot.redroid_height=1280 \
  androidboot.redroid_dpi=320
## Linux perf 监控命令： 
perf record -ag -F99 -o perf-test2.data sleep 60
## 客户端连接
adb connect 43.206.94.215:5002
scrcpy -s 43.206.94.215:5002 --no-audio --video-bit-rate=2M

# 测试 3：容器启动 设置  --cpuset-cpus="0", 优化 scrcpy 连接参数
docker run -itd --rm --privileged --cpuset-cpus="0" \
  -v ~/redroid11_tiktok-33.7.2:/data -p 5002:5555 redroid/redroid:11.0.0-latest \
  androidboot.redroid_width=720 \
  androidboot.redroid_height=1280 \
  androidboot.redroid_dpi=320
## Linux perf 监控命令： 
perf record -ag -F99 -o perf-test3.data sleep 60
## 客户端连接
adb connect 43.206.94.215:5002
scrcpy -s 43.206.94.215:5002 --no-audio --video-bit-rate=2M --max-size=900 --max-fps=24 --display-buffer=100


# 测试 4：容器启动不设置 --cpuset-cpus
## 启动容器
docker run -itd --rm --privileged \
  -v ~/redroid13_tiktok-32.5.1:/data -p 5003:5555 redroid/redroid:13.0.0-latest \
  androidboot.redroid_width=720 \
  androidboot.redroid_height=1280 \
  androidboot.redroid_dpi=320
## Linux perf 监控命令： 
perf record -ag -F99 -o perf-test4.data sleep 60
## 客户端连接
adb connect 43.206.94.215:5003
scrcpy -s 43.206.94.215:5003 --no-audio --video-bit-rate=2M


## 底线测试，20240326
# 测试 5：Redroid 13 容器启动设置 --cpuset-cpus="0" (1 vCPU)
# 分辨率调整为 480P，DPI 等比例调整为 213
## 启动容器
docker run -itd --rm --privileged --cpuset-cpus="0" \
  -v ~/data:/data -p 5005:5555 redroid/redroid:13.0.0-latest \
  androidboot.redroid_width=480 \
  androidboot.redroid_height=853 \
  androidboot.redroid_dpi=213
## 客户端连接: 传输码率 1M，设置 100ms 显示缓存
adb connect 18.181.209.212:5008
scrcpy -s 18.181.209.212:5008 --no-audio --video-bit-rate=1M --display-buffer=100


## 其他测试，20240327: 最新 tiktok-34
# 测试 6：Redroid 13 容器启动设置 --cpuset-cpus="0" (1 vCPU)
## 启动容器
docker run -itd --rm --privileged --cpuset-cpus="0" \
  -v ~/data5006:/data -p 5006:5555 redroid/redroid:13.0.0-latest \
  androidboot.redroid_width=540 \
  androidboot.redroid_height=960 \
  androidboot.redroid_dpi=240

## 客户端连接: 传输码率 1M，设置 100ms 显示缓存
adb connect 18.181.209.212:5006
scrcpy -s 18.181.209.212:5006 --no-audio --video-bit-rate=2M --max-size=900  --display-buffer=100

