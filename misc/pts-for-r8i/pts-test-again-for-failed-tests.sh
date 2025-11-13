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
for testname in ${tests} 
do
    timestamp=$(date +%Y%m%d%H%M%S)
    echo "[INFO][${timestamp}] Start to test ${testname} ......"
    echo "${testname}-${timestamp}.txt:" >> ${DATA_DIR}/pts-result-url-summary.txt
    phoronix-test-suite batch-benchmark ${testname} > ${PTS_RESULT_DIR}/${testname}-${timestamp}.txt
    grep "Results Uploaded To" ${PTS_RESULT_DIR}/${testname}-${timestamp}.txt >> ${DATA_DIR}/pts-result-url-summary.txt
    sleep 5
done
echo "[INFO][$(date +%Y%m%d%H%M%S)] StepX: Complete to rerun some previous FAILED TESTS."

