#!/bin/bash

set -uo pipefail

SUT_NAME="es_ssd"
source /tmp/temp-setting

# ============ 配置区（按需修改）============
IPADDR="${IPADDR:-127.0.0.1}" # ES 集群地址
INSTANCE_TYPE="${INSTANCE_TYPE:-unknown}" # EC2 实例类型
PIPELINE="${PIPELINE:-benchmark-only}"  # benchmark-only=连外部ES；from-distribution=Rally自建
OFFLINE="${OFFLINE:-false}"          # 离线模式
OPTS=()
[ "$OFFLINE" = "true" ] && OPTS+=(--offline)

# ============ 定制测试场景 ============
# declare -a FULL_TESTS=(
#     "geonames:append-no-conflicts:冒烟测试-地理空间"
# )

declare -a FULL_TESTS=(
    "nyc_taxis:aggs:聚合查询(CPU/分支预测/L2缓存)"
    "nyc_taxis:esql:ESQL新查询引擎"
    "wikipedia:index-and-search:全文检索综合"
    "so_vector:index-and-search:向量检索(SIMD)"
    "http_logs:append-no-conflicts:日志场景"
    "big5:big5:五大主要场景"
)
# ============ 定制测试场景 - END ============

RESULT_PATH="/root/ec2-test-suite/benchmark-result-files"
mkdir -p ${RESULT_PATH}

# ============ 执行测试 ============
for combo in "${FULL_TESTS[@]}"; do
    IFS=':' read -r track challenge desc <<< "$combo"
    echo "-------------------------------------------------------------------"
    echo ">>> Track: $track | Challenge: $challenge"
    echo "    说明: $desc"
    echo "-------------------------------------------------------------------"

    ttt=$(date +%Y%m%d%H%M%S)
    RACE_ID=${SUT_NAME}_${INSTANCE_TYPE}_${IPADDR}_${track}-${challenge}
    RESULT_FILE="${RESULT_PATH}/${RACE_ID}.txt"

    ## 启动一个后台进程，执行dool命令，获取系统性能信息
    DOOL_FILE="${RESULT_PATH}/${RACE_ID}_dool-sut.txt"
    ssh -o StrictHostKeyChecking=no -i ~/.aws/${KEY_NAME}.pem ec2-user@${IPADDR} \
      "dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60" \
      1>> ${DOOL_FILE} 2>&1 &
    DOOL_FILE_LOADGEN="${RESULT_PATH}/${RACE_ID}_dool-loadgen.txt"
    nohup dool --cpu --sys --mem --net --net-packets --disk --io --proc-count --time --bits 60 \
      1>> ${DOOL_FILE_LOADGEN} 2>&1 &

    esrally race \
        --track="${track}" \
        --challenge="${challenge}" \
        --target-hosts=http://${IPADDR}:9200 \
        --pipeline="${PIPELINE}" \
        --race-id="${RACE_ID}" \
        --on-error=continue --kill-running-processes "${OPTS[@]}" \
        1>${RESULT_FILE} 2>&1

    # 跑完一个 track 后看实际占用
    curl -s "http://${IPADDR}:9200/_cat/indices?v&h=index,docs.count,store.size&s=store.size:desc" >> ${RACE_ID}.log
    curl -s "http://${IPADDR}:9200/_cat/allocation?v&h=node,disk.used,disk.avail,disk.percent" >> ${RACE_ID}.log

    # 删除 track 在 ES 中的数据
    curl -sX DELETE "http://${IPADDR}:9200/${track}" && echo "已删除: $track" >> ${RACE_ID}.log
    # 等待段文件真正释放
    sleep 10 && curl -s "http://${IPADDR}:9200/_cat/allocation?v" >> ${RACE_ID}.log

done
