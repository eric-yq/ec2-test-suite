#!/bin/bash

######################################################################
## 使用场景：已经完整过执行了一次PTS多项目测试，但是有一些 test 失败了，重新执行。
## 并将某个testname的结果追加到某个已知的结果集。
## 例如：2609235-NE-R6A4XLARG84
## results="$1"
######################################################################

## 查询 pts-result 目录下已经执行完成的日志文件中的错误信息，
# grep -iE "err|fail" *.txt 
# 然后逐个分析是否需要再次执行。

cd /root/
source /root/.bash_profile
echo "yuanquan: TEST_RESULTS_IDENTIFIER=${PN}, TEST_RESULTS_DESCRIPTION=${PN}, TEST_RESULTS_NAME=${PN}"

## 执行基准测试(标准)
echo "[INFO] Step1: Start to perform PTS tests ..."

tests="ffmpeg"
for testname in ${tests} 
do
    # 启动一个监控
    DOOL_FILE="${PTS_RESULT_DIR}/${testname}-dool.txt"
    dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 30 > ${DOOL_FILE} 2>&1 &
    DOOL_PID=$!
    # 执行基准测试
    FORCE_TIMES_TO_RUN=3 phoronix-test-suite batch-benchmark ${testname} --result-file=${results} \
      > ${PTS_RESULT_DIR}/${testname}.txt
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
DATATIME=$(date +%Y%m%d.%H%M%S)
tar czfP ${DATA_DIR}-fix-failed-tests-${DATATIME}.tar.gz ${DATA_DIR}
aws_s3_bucket_name=$(aws s3 ls | awk '{print $3}' | grep ec2-core-benchmark | head -1)
aws s3 cp ${DATA_DIR}-fix-failed-tests-${DATATIME}.tar.gz s3://${aws_s3_bucket_name}/result_pts/ && \
echo "[INFO] Step3: Result files have been uploaded to s3 bucket. BYE BYE."

# Disable 服务，这样 reboot 后不会再次执行
systemctl stop    userdata.service
systemctl disable userdata.service

## 停止实例
INSTANCE_ID=$(ec2-metadata --quiet --instance-id)
aws ec2 stop-instances --instance-ids "${INSTANCE_ID}"
