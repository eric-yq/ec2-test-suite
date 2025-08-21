#!/bin/bash 

sudo su - root

################################################################################
## Amazon Linux 2023, GCC 14（Graviton4 需要 GCC 13 以上支持 -march armv9 的参数）
## 安装依赖包
yum install -y awscli autoconf automake bzip2 bzip2-devel cmake freetype-devel \
  gcc14 gcc14-c++ git libtool make pkgconfig zlib-devel nasm yasm p7zip htop

## 下载软件包
cd /root/ && rm -rf x264 x265_git ffmpeg-*
git clone https://code.videolan.org/videolan/x264.git
git clone https://bitbucket.org/multicoreware/x265_git
ver="6.1.3"
wget https://ffmpeg.org/releases/ffmpeg-$ver.tar.xz
tar xf ffmpeg-$ver.tar.xz

## 编译安装 x264
cd /root/x264/
./configure --prefix="/root/ffmpeg_build" --bindir="/root/ffmpeg_build/bin" --enable-static 
 make -j && make install && \
 echo "[INFO] $(date +%Y%m%d%H%M%S): x264 complied." 

## 编译安装 x265
cd /root/x265_git/build/linux
cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="/root/ffmpeg_build" \
 -DENABLE_SHARED:bool=off ../../source

cmake \
  -DCMAKE_C_COMPILER=gcc14-gcc \
  -DCMAKE_CXX_COMPILER=gcc14-g++ \
  -DCMAKE_ASM_COMPILER=gcc14-as \
  -DCMAKE_ASM_FLAGS="-march=armv8.2-a" \
  -DCMAKE_C_FLAGS="-march=armv8.2-a" \
  -DCMAKE_CXX_FLAGS="-march=armv8.2-a" \
  -G "Unix Makefiles" \
  -DCMAKE_INSTALL_PREFIX="/root/ffmpeg_build" \
  -DENABLE_SHARED:bool=off \
  ../../source

make -j && make install && \
 echo "[INFO] $(date +%Y%m%d%H%M%S): x265 complied."
 
## 编译安装 ffmpeg
cd /root/ffmpeg-$ver/
PATH="/root/bin:$PATH" PKG_CONFIG_PATH="/root/ffmpeg_build/lib/pkgconfig" \
 ./configure \
 --prefix="/root/ffmpeg_build" --bindir="/root/ffmpeg_build/bin" \
 --pkg-config-flags="--static" \
 --extra-cflags="-I/root/ffmpeg_build/include" \
 --extra-ldflags="-L/root/ffmpeg_build/lib" \
 --extra-libs=-lpthread --extra-libs=-lm \
 --enable-gpl --enable-libx264 --enable-libx265 \
 --enable-nonfree
make -j && make install &&
 echo "[INFO] $(date +%Y%m%d%H%M%S): ffmpeg complied" 
echo "PATH=/root/ffmpeg_build/bin:$PATH" >> /etc/profile
source /etc/profile
ffmpeg -version
ffmpeg -hide_banner -codecs |grep 265
ffmpeg -hide_banner -codecs |grep 264

################################################################################
## 测试 ffmpeg 编码性能
# 配置 AWS CLI
# ......
## 下载 3 个视频文件 
cd /root/
aws s3 cp --recursive s3://ec2-core-benchmark-ericyq/insta360-videos/ .
mv PRO_VID_20220121_143251_00_005.mp4 input1.mp4
mv PRO_VID_20220129_120530_00_055.mp4 input2.mp4
mv VID_20180105_184256_00_172.mp4 input3.mp4

### X265 用例 -- CPU
# test0: x265, input1, ultrafast
# test1: x265, input1, medium
# test2: x265, input2, ultrafast
# test3: x265, input3, medium
# test4: x265, input3, ultrafast
# test5: x265, input3, medium
### X264 用例 -- CPU
# test6: x264, input1, ultrafast
# test7: x264, input1, medium
# test8: x264, input2, ultrafast
# test9: x264, input3, medium
# test10: x264, input3, ultrafast
# test11: x264, input3, medium
declare -a tests=(0 1 2 3 4 5 6 7 8 9 10 11)
declare -a c=(libx265 libx265 libx265 libx265 libx265 libx265 libx264 libx264 libx264 libx264 libx264 libx264)
declare -a r=(input1.mp4 input1.mp4 input2.mp4 input2.mp4 input3.mp4 input3.mp4 \
              input1.mp4 input1.mp4 input2.mp4 input2.mp4 input3.mp4 input3.mp4)
declare -a p=(ultrafast medium ultrafast medium ultrafast medium ultrafast medium ultrafast medium ultrafast medium)

## 执行测试
for t in ${tests[@]}
do
    input=${r[t]}
    output="${input}__test${t}__output.mp4"
    RESULT_FILE="temp-output-${t}.txt"
    
    echo "[INFO] $(date +%Y%m%d%H%M%S): perform testcase-${t}: Codec=${c[t]}, Preset=${p[t]}, InputFile：$(du -smh $input)" \
      > ${RESULT_FILE}

    ffmpeg -y -noautorotate -threads $(nproc) -i ${input} -c:v ${c[t]} \
      -preset ${p[t]} -crf 28 -g 32 -b:v 30M -c:a copy  \
      ${output} 1>>${RESULT_FILE} 2>&1
     
    echo "[INFO] $(date +%Y%m%d%H%M%S): OutputFile：$(du -smh $output)" >> ${RESULT_FILE}
done

## 汇总结果并打包
instance_type=$(cloud-init query ds.meta_data.instance_type)
timestamp=$(date +%Y%m%d-%H%M%S)
archive="ffmpeg_result_${instance_type}_${timestamp}"

mkdir -p ${archive}
cp *.txt *.sh ${archive}
ffmpeg -version  > ${archive}/filesize.txt
ffmpeg -hide_banner -codecs > ${archive}/filesize.txt
du -smh *.mp4 > ${archive}/filesize.txt
tar czf ${archive}.tar.gz ${archive}/
aws s3 cp ${archive}.tar.gz s3://ec2-core-benchmark-ericyq/result_ffmpeg/