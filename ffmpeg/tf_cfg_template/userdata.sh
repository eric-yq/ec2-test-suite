#!/bin/bash

# 实例启动成功之后的首次启动 OS， /root/userdata.sh 不存在，创建该 userdata.sh 文件并设置开启自动执行该脚本。
if [ ! -f "/root/userdata.sh" ]; then
    echo "首次启动 OS, 未找到 /root/userdata.sh，准备创建..."
    # 复制文件
    cp /var/lib/cloud/instance/scripts/part-001 /root/userdata.sh
    chmod +x /root/userdata.sh
    # 创建 systemd 服务单元
    cat > /etc/systemd/system/userdata.service << EOF
[Unit]
Description=Execute userdata script at boot
After=network.target

[Service]
Type=oneshot
User=root
ExecStart=/root/userdata.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    # 启用服务
    systemctl daemon-reload
    systemctl enable userdata.service
    
    echo "已创建并启用 systemd 服务 userdata.service"

    ### 如果 5 分钟之后，实例没有重启，或者也有可能不需要重启，则开始启动服务执行后续安装过程。
    sleep 300
    systemctl start userdata.service
    exit 0
fi

############## 
## 安装依赖包
yum install -yq awscli autoconf automake bzip2 bzip2-devel cmake freetype-devel zip python3-pip \
  gcc gcc-c++ git libtool make pkgconfig zlib-devel nasm yasm p7zip htop git cmake screen
pip3 install dool 

## 使用 GCC 14 编译
yum install -y gcc14 gcc14-c++
export CC=/usr/bin/gcc14-cc
export CXX=/usr/bin/gcc14-g++

cd /root/ && rm -rf x264 x265_git ffmpeg-*

## 编译安装 x264
cd /root/
git clone https://code.videolan.org/videolan/x264.git
cd /root/x264/
./configure --prefix="/root/ffmpeg_build" --bindir="/root/ffmpeg_build/bin" --enable-static 
make -j $(nproc) && make install && \
 echo "[INFO] $(date +%Y%m%d%H%M%S): x264 complied." 

## 编译安装 x265， arm 上安装 gcc14
cd /root/
ver=4.1
wget https://bitbucket.org/multicoreware/x265_git/downloads/x265_$ver.tar.gz
tar zxf x265_$ver.tar.gz
cd /root/x265_$ver/build/linux
cmake -G "Unix Makefiles" \
 -DCMAKE_INSTALL_PREFIX="/root/ffmpeg_build" \
 -DCMAKE_C_FLAGS="-Wno-unused-variable -Wunused-parameter" \
 -DCMAKE_CXX_FLAGS="-Wno-unused-variable -Wunused-parameter" \
 -DENABLE_SHARED:bool=off ../../source
make -j && make install && \
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
make -j  && make install &&
 echo "[INFO] $(date +%Y%m%d%H%M%S): ffmpeg complied" 
echo "PATH=/root/ffmpeg_build/bin:$PATH" >> /etc/profile
source /etc/profile
ffmpeg -version
ffmpeg -hide_banner -codecs |grep 265
ffmpeg -hide_banner -codecs |grep 264

################################################################################
## 测试 ffmpeg 编码性能
# 配置 AWS CLI
aws_ak_value="akxxx"
aws_sk_value="skxxx"
aws_region_name=$(cloud-init query region)
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

# 停止实例
INSTANCE_ID=$(ec2-metadata --quiet --instance-id)
REGION_ID=$(ec2-metadata --quiet --region)
aws ec2 terminate-instances --instance-ids "${INSTANCE_ID}" --region "${REGION_ID}"
