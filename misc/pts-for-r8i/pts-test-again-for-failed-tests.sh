#!/bin/bash

## 使用场景：已经完整过执行了一次PTS多项目测试，但是有一些 test 失败了，环境还在。

## 查询 pts-result 目录下已经执行完成的日志文件中的错误信息，
# grep -iE "err|fail" *.txt 
# 然后逐个分析是否需要再次执行。

##########################################################################
# 需要重新测试的 test 项目，通过脚本执行时的参数带入，例如 "botan nginx scylladb"
# tests="$@"
##########################################################################

cd /root/
source /root/.bash_profile
echo "yuanquan: TEST_RESULTS_IDENTIFIER=${PN}, TEST_RESULTS_DESCRIPTION=${PN}, TEST_RESULTS_NAME=${PN}"

## 开始执行
echo "[INFO][$(date +%Y%m%d%H%M%S)] StepX: Start to test some FAILED TESTS: ${tests} ..."
echo "[INFO][$(date +%Y%m%d%H%M%S)] Followinig tests will be re-run ... " >> ${DATA_DIR}/pts-result-url-summary.txt

# 关闭 checksum
export NO_FILE_HASH_CHECKS=1

## 执行基准测试(标准)
echo "[INFO] Step1: Start to perform PTS tests ..."

tests="gmpbench primesieve stream cachebench ramspeed compress-zstd compress-lz4 blosc \
  botan john-the-ripper cython-bench ffmpeg x264 x265 tjbench vvenc blogbench nginx \
  graphics-magick smallpt draco renaissance dacapobench java-scimark2 scimark2 \
  redis memtier-benchmark valkey keydb dragonflydb pogocache tidb sonicjson simdjson \
  cassandra scylladb mariadb rocksdb influxdb clickhouse duckdb leveldb cockroach couchdb \
  stockfish mt-dgemm perf-bench mlpack mnn whisper-cpp whisperfile opencv \
  "
for testname in ${tests} 
do
    # 启动一个监控
    DOOL_FILE="${PTS_RESULT_DIR}/${testname}-dool.txt"
    dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 30 > ${DOOL_FILE} 2>&1 &
    DOOL_PID=$!
    # 执行基准测试
    FORCE_TIMES_TO_RUN=3 phoronix-test-suite batch-benchmark ${testname} > ${PTS_RESULT_DIR}/${testname}.txt
    # 保存结果 URL
    echo "${testname}:" >> ${DATA_DIR}/test-report-url-summary.txt
    phoronix-test-suite info ${testname} | grep "Description: "  >> ${DATA_DIR}/test-report-url-summary.txt
    grep "Results Uploaded To" ${PTS_RESULT_DIR}/${testname}.txt >> ${DATA_DIR}/test-report-url-summary.txt
    # 停止监控
    kill -9 ${DOOL_PID}

    sleep 5
done

## 执行时间太长的，设置为只执行 1 次的tests:
tests1="openssl pyperformance cpp-perf-bench c-ray lczero arrayfire hpcg quantlib"
for testname in ${tests1} 
do
    # 启动一个监控
    DOOL_FILE="${PTS_RESULT_DIR}/${testname}-dool.txt"
    dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60 > ${DOOL_FILE} 2>&1 &
    DOOL_PID=$!
    # 执行基准测试
    FORCE_TIMES_TO_RUN=1 phoronix-test-suite batch-benchmark ${testname} > ${PTS_RESULT_DIR}/${testname}.txt
    # 保存结果 URL
    echo "${testname}:" >> ${DATA_DIR}/test-report-url-summary.txt
    phoronix-test-suite info ${testname} | grep "Description: "  >> ${DATA_DIR}/test-report-url-summary.txt
    grep "Results Uploaded To" ${PTS_RESULT_DIR}/${testname}.txt >> ${DATA_DIR}/test-report-url-summary.txt
    # 停止监控
    kill -9 ${DOOL_PID}

    sleep 5
done

## 特殊任务：执行2次的tests。
tests2="scikit-learn"
for testname in ${tests2} 
do
    # 启动一个监控
    DOOL_FILE="${PTS_RESULT_DIR}/${testname}-dool.txt"
    dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60 > ${DOOL_FILE} 2>&1 &
    DOOL_PID=$!
    # 执行基准测试
    FORCE_TIMES_TO_RUN=2 phoronix-test-suite batch-benchmark ${testname} > ${PTS_RESULT_DIR}/${testname}.txt
    # 保存结果 URL
    echo "${testname}:" >> ${DATA_DIR}/test-report-url-summary.txt
    phoronix-test-suite info ${testname} | grep "Description: "  >> ${DATA_DIR}/test-report-url-summary.txt
    grep "Results Uploaded To" ${PTS_RESULT_DIR}/${testname}.txt >> ${DATA_DIR}/test-report-url-summary.txt
    # 停止监控
    kill -9 ${DOOL_PID}

    sleep 5
done

echo "[INFO] Step: Complete ALL PTS TESTS."

# 所有结果打包并上传到 S3 bucket
phoronix-test-suite list-installed-tests > ${DATA_DIR}/pts-list-installed-tests.txt
ls -ltr ${PTS_RESULT_DIR} >> ${DATA_DIR}/pts-list-installed-tests.txt
df -h  >> ${DATA_DIR}/pts-list-installed-tests.txt
rm -rf ${LOG_DIR}/*
cp -r /var/log/cloud-init*.log /var/log/phoronix-test-suite-*.log /var/lib/cloud/ /root/userdata.sh ${LOG_DIR}
tar czfP ${DATA_DIR}-all.tar.gz ${DATA_DIR}
aws_s3_bucket_name=$(aws s3 ls | awk '{print $3}' | grep ec2-core-benchmark | head -1)
aws s3 cp ${DATA_DIR}-all.tar.gz s3://${aws_s3_bucket_name}/result_pts/ && \
echo "[INFO] Step3: Result files have been uploaded to s3 bucket. BYE BYE."

## Disable 服务，这样 reboot 后不会再次执行
systemctl disable userdata.service

## 停止实例
INSTANCE_ID=$(ec2-metadata --quiet --instance-id)
aws ec2 stop-instances --instance-ids "${INSTANCE_ID}"
