#!/bin/bash
# IPADDR=${1}
# INSTANCE_TYPE=${2}

######## 安装ESRally ######## 
ESROOTDISK="/mnt/nvme1n1"   ## for i4g/i4i/i7ie/i8g

mkdir -p $ESROOTDISK/esrally_benchmark /root/.rally 
ln -s $ESROOTDISK/esrally_benchmark /root/.rally/benchmarks

yum install -y python3-pip python3-devel git gcc gcc-c++ htop
pip3 install dool
pip3 install esrally --ignore-installed requests
pip3 install pytrec_eval==0.5 numpy==1.24.0 --upgrade --target /root/.rally/libs

mkdir -p /root/.rally/benchmarks/tracks 
cd /root/.rally/benchmarks/tracks 
git clone https://github.com/elastic/rally-tracks.git

# 安装pbzip2，多线程解压缩工具
cd /root/
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(arch).sh
bash Miniconda3-latest-Linux-$(arch).sh -b -p /root/miniconda3/
eval "$(/root/miniconda3/bin/conda shell.bash hook)"
conda init
source /root/.bashrc
conda config --add channels conda-forge
conda config --set channel_priority strict
conda install -y pbzip2
ln -s /root/miniconda3/bin/pbzip2  /usr/bin/pbzip2

cd /root/
vi benchmark.sh
################################################################################
#!/bin/bash
# IPADDR=${1}
# INSTANCE_TYPE=${2}
tracks=${1}

# esrally on localhost
IPADDR="127.0.0.1"
INSTANCE_TYPE=$(ec2-metadata --quiet --instance-type)

# tracks="nested noaa sql pmc http_logs so_vector so geoshape wikipedia k8s_metrics openai_vector github_archive eql"

for i in ${tracks}
do
    ttt=$(date +%Y%m%d%H%M%S)
    RACE_ID=esrally-${INSTANCE_TYPE}-${i}-${ttt}
    esrally race --track-repository=rally-tracks --track=${i} \
      --pipeline=benchmark-only --race-id=${RACE_ID} \
      --target-hosts=http://${IPADDR}:9200 \
      > ${RACE_ID}.log
done
#######

nohup bash benchmark.sh &


###################
# reboot 后启动
VERSION="7.13.4"
esuser="ec2-user"
IPADDR="127.0.0.1"
ESROOTDISK="/mnt/nvme1n1" 
# ESROOTDISK="/mnt/nvme0n1" 
su ${esuser} -c "$ESROOTDISK/elasticsearch/bin/elasticsearch -d -p pid"
echo "[$(date)] Wait for ElasticSearch start successfully."
sleep 30
curl -XGET http://$IPADDR:9200/_cat/health?v
nohup bash benchmark.sh &

###################














# esrally on localhost
IPADDR=$(hostname -i)
INSTANCE_TYPE=$(ec2-metadata --quiet --instance-type)

tracks="nested noaa sql pmc http_logs so_vector so geoshape nyc_taxis wikipedia \
        k8s_metrics openai_vector github_archive eql"

for i in ${tracks} 
do
    ttt=$(date +%Y%m%d%H%M%S)
    RACE_ID=esrally-${INSTANCE_TYPE}-${i}-${ttt}
    esrally race --track-repository=rally-tracks --track=${i} \
      --pipeline=benchmark-only --race-id=${RACE_ID} \
      --target-hosts=http://${IPADDR}:9200 > ${RACE_ID}.log
done
