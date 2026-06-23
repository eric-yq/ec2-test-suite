#!/bin/bash

## 使用场景：已经完整过执行了一次PTS多项目测试，但是有一些 test 失败了，环境还在。

## 查询 pts-result 目录下已经执行完成的日志文件中的错误信息，
# grep -iE "err|fail" *.txt 
# 然后逐个分析是否需要再次执行。

##########################################################################
# 需要重新测试的 test 项目，通过脚本执行时的参数带入，例如 "botan nginx scylladb"
tests="$@"
##########################################################################

cd /root/
source /root/.bash_profile
echo "yuanquan: TEST_RESULTS_IDENTIFIER=${PN}, TEST_RESULTS_DESCRIPTION=${PN}, TEST_RESULTS_NAME=${PN}"

## 设置变量
PN=$(dmidecode -s system-product-name | tr ' ' '_')
export TEST_RESULTS_IDENTIFIER=${PN}
export TEST_RESULTS_DESCRIPTION=${PN}
export TEST_RESULTS_NAME=${PN}

## 开始执行
echo "[INFO][$(date +%Y%m%d%H%M%S)] StepX: Start to test some FAILED TESTS: ${tests} ..."
echo "[INFO][$(date +%Y%m%d%H%M%S)] Followinig tests will be re-run ... " >> ${DATA_DIR}/pts-result-url-summary.txt

tests="gmpbench primesieve stream cachebench ramspeed compress-zstd compress-lz4 blosc \
  botan john-the-ripper cython-bench ffmpeg x264 x265 tjbench vvenc blogbench nginx \
  graphics-magick smallpt draco renaissance dacapobench java-scimark2 scimark2 \
  redis memtier-benchmark valkey keydb dragonflydb pogocache sonicjson simdjson \
  cassandra scylladb rocksdb influxdb clickhouse duckdb leveldb \
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

echo "[INFO] Step: Complete ALL PTS TESTS."

