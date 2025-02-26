#!/bin/bash
# IPADDR=${1}
# INSTANCE_TYPE=${2}

# esrally on localhost
IPADDR=$(hostname -i)
INSTANCE_TYPE=$(cloud-init query ds.meta_data.instance_type)

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
