#!/bin/bash 

sudo su - root

################################################################################
## 安装依赖包
yum install -y awscli autoconf automake bzip2 bzip2-devel cmake freetype-devel zip \
  gcc gcc-c++ git libtool make pkgconfig zlib-devel nasm yasm p7zip htop git cmake screen
cd /root/ && rm -rf x264 x265_git ffmpeg-*

## 编译安装 x264
cd 
git clone https://code.videolan.org/videolan/x264.git
cd /root/x264/
./configure --prefix="/root/ffmpeg_build" --bindir="/root/ffmpeg_build/bin" --enable-static 
make -j $(nproc) && make install && \
 echo "[INFO] $(date +%Y%m%d%H%M%S): x264 complied." 

## 编译安装 x265， arm 上安装 gcc13
yum install gcc-toolset-13-gcc gcc-toolset-13-gcc-c++
scl enable gcc-toolset-13
ver=4.1
wget https://bitbucket.org/multicoreware/x265_git/downloads/x265_$ver.tar.gz
tar zxf x265_$ver.tar.gz
cd /root/x265_$ver/build/linux
cmake -G "Unix Makefiles" \
 -DCMAKE_INSTALL_PREFIX="/root/ffmpeg_build" \
 -DCMAKE_C_FLAGS="-Wno-unused-variable -Wunused-parameter" \
 -DCMAKE_CXX_FLAGS="-Wno-unused-variable -Wunused-parameter" \
 -DENABLE_SHARED:bool=off ../../source
make -j $(nproc) && make install && \
 echo "[INFO] $(date +%Y%m%d%H%M%S): x265 complied."
 
## 编译安装 ffmpeg
cd 
ver="6.1.3"
wget https://ffmpeg.org/releases/ffmpeg-$ver.tar.xz
tar xf ffmpeg-$ver.tar.xz
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
make -j `nproc` && make install &&
 echo "[INFO] $(date +%Y%m%d%H%M%S): ffmpeg complied" 
echo "PATH=/root/ffmpeg_build/bin:$PATH" >> /etc/profile
source /etc/profile
ffmpeg -version
ffmpeg -hide_banner -codecs |grep 265
ffmpeg -hide_banner -codecs |grep 264

################################################################################
## 测试 ffmpeg 编码性能
# 配置 AWS CLI
aws_ak_value="xxx"
aws_sk_value="+xxx"
aws_region_name=us-east-2
aws configure set aws_access_key_id ${aws_ak_value}
aws configure set aws_secret_access_key ${aws_sk_value}
aws configure set default.region ${aws_region_name}
aws_s3_bucket_name="s3://ec2-core-benchmark-ericyq"
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
instance_type=$(ec2-metadata --quiet --instance-type)
timestamp=$(date +%Y%m%d-%H%M%S)
archive="ffmpeg_result_${instance_type}_${timestamp}"

mkdir -p ${archive}
cp *.txt *.sh ${archive}
ffmpeg -version  > ${archive}/filesize.txt
ffmpeg -hide_banner -codecs > ${archive}/filesize.txt
du -smh *.mp4 > ${archive}/filesize.txt
tar czf ${archive}.tar.gz ${archive}/
aws s3 cp ${archive}.tar.gz s3://ec2-core-benchmark-ericyq/result_ffmpeg/