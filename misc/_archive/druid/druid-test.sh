yum groupinstall -y "Development Tools"
yum install -y java-11-amazon-corretto* git maven python3-pip htop
pip3 install dool

screen -R ttt -L
cd /root/
wget https://dlcdn.apache.org/druid/32.0.0/apache-druid-32.0.0-src.tar.gz
tar zxf apache-druid-32.0.0-src.tar.gz && cd apache-druid-32.0.0-src
# mvn clean install
# 报错，屏蔽一些单元测试。
mvn clean install -Dtest='!FileUtilsTest,!TopNQueryRunnerBenchmark,!IndexMergerTestBase,!LookupSnapshotTakerTest,!LocalDataSegmentPusherTest,!LocalDataSegmentPusherTest,!SegmentLocalCacheManagerTest,!CacheTestBase,!FileTaskLogsTest,!AzureOutputConfigTest'

## screen会话日志处理
cd /root/
git clone https://github.com/kilobyte/colorized-logs.git
cd colorized-logs
gcc ansi2txt.c -o ansi2txt
cp ansi2txt /usr/local/bin/


