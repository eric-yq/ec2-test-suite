
#################################################################################################################
# TPCH 准备数据：下面内容可以保存为 prepare-tpch300.sh , 然后执行。
# screen -R ttt -L
#!/bin/bash
sf=300
tiup bench tpch prepare \
  --sf $sf --dropdata --threads 16 \
  --host ${tidb_host} --port 4000 --db tpch${sf} \
  --analyze \
  --tidb_build_stats_concurrency 4 \
  --tidb_distsql_scan_concurrency 15 \
  --tidb_index_serial_scan_concurrency 4 \
  --tiflash-replica 3

echo "[Info] Complete to prepare tpch${sf}." && sleep 60
echo "[Info] Start to analyze tables..."
# 分析表统计信息的单独 SQL
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpch${sf}.customer;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpch${sf}.lineitem;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpch${sf}.nation;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpch${sf}.orders;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpch${sf}.part;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpch${sf}.partsupp;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpch${sf}.region;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpch${sf}.supplier;"

echo "[Info] Complete to prepare and analyze tpch${sf}, you can start to run benchmark."
#################################################################################################################
bash prepare-tpch300.sh

#################################################################################################################
## 常用操作 eks-and-tidb-commands.sh
#################################################################################################################

#################################################################################################################
# 运行 TPC-H 查询
# 执行测试: q4 查询有点问题，先不执行
# screen -R ttt -L
sf=300
LIST="q1 q2 q3 q5 q6 q7 q8 q9 q10 q11 q12 q13 q14 q15 q16 q17 q18 q19 q20 q21 q22"
for i in $LIST; do
  tiup bench tpch run \
    --host ${tidb_host} --port 4000 --db tpch${sf} \
    --conn-params="tidb_isolation_read_engines = 'tiflash'" \
    --conn-params="tidb_allow_mpp = 1" \
    --conn-params="tidb_enforce_mpp = 1" \
    --conn-params="tidb_opt_tiflash_concurrency_factor = 4" \
    --conn-params="tidb_opt_mpp_outer_join_fixed_build_side = 0" \
    --conn-params="tiflash_mpp_task_max_concurrency = 8" \
    --conn-params="tidb_mem_quota_query = 137438953472" \
    --conn-params="tidb_broadcast_join_threshold_count=10000000" \
    --conn-params="tidb_broadcast_join_threshold_size=104857600" \
    --count 3 \
    --queries "$i" >> result_tpch${sf}.txt 2>&1
    
  sleep 10  
done
echo "[Info] Complete to run tpch${sf} tests."
grep Summary result_tpch${sf}.txt > result_summary_tpch${sf}_${INSTANCE_FAMILY}.txt

#################################################################################################################
# TPCC 准备数据：下面内容可以保存为 prepare-tpcc1000.sh , 然后执行。
# screen -R ttt -L
#!/bin/bash
source .bash_profile
wares=1000
tiup bench tpcc prepare \
  --host ${tidb_host} --port 4000 \
  --db tpcc${wares} --warehouses ${wares} --dropdata \
  --threads 16 --parts 16 --isolation 2 \
  --conn-params "tidb_batch_insert=1" \
  --conn-params "tidb_batch_delete=1" \
  --conn-params "tidb_enable_streaming=1" \
  --conn-params "tidb_disable_txn_auto_retry=0" \
  --conn-params "tidb_constraint_check_in_place=0" \
  --conn-params "tidb_txn_mode=optimistic" \
  --conn-params "tidb_enable_batch_dml=1" \
  --conn-params "tidb_dml_batch_size=2000" \
  --conn-params "tidb_distsql_scan_concurrency=16" \
  --conn-params "tidb_index_serial_scan_concurrency=8" \
  --conn-params "tidb_projection_concurrency=8" \
  --conn-params "tidb_hashagg_partial_concurrency=8" \
  --conn-params "tidb_hashagg_final_concurrency=8" \
  --conn-params "tidb_init_chunk_size=1024" \
  --conn-params "tidb_max_chunk_size=4096" \
  --conn-params "tidb_mem_quota_query=8 << 30" 

# 收集统计信息
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpcc${wares}.customer;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpcc${wares}.district;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpcc${wares}.history;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpcc${wares}.item;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpcc${wares}.new_order;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpcc${wares}.order_line;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpcc${wares}.orders;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpcc${wares}.stock;"
mysql -h ${tidb_host} -P 4000 -u root -e "ANALYZE TABLE tpcc${wares}.warehouse;"

# 查看各个表的记录数
wares=1000
mysql -h ${tidb_host} -P 4000 -u root -e "SELECT COUNT(*) FROM tpcc${wares}.customer;"
mysql -h ${tidb_host} -P 4000 -u root -e "SELECT COUNT(*) FROM tpcc${wares}.district;"
mysql -h ${tidb_host} -P 4000 -u root -e "SELECT COUNT(*) FROM tpcc${wares}.history;"
mysql -h ${tidb_host} -P 4000 -u root -e "SELECT COUNT(*) FROM tpcc${wares}.item;"
mysql -h ${tidb_host} -P 4000 -u root -e "SELECT COUNT(*) FROM tpcc${wares}.new_order;"
mysql -h ${tidb_host} -P 4000 -u root -e "SELECT COUNT(*) FROM tpcc${wares}.order_line;"
mysql -h ${tidb_host} -P 4000 -u root -e "SELECT COUNT(*) FROM tpcc${wares}.orders;"
mysql -h ${tidb_host} -P 4000 -u root -e "SELECT COUNT(*) FROM tpcc${wares}.stock;"
mysql -h ${tidb_host} -P 4000 -u root -e "SELECT COUNT(*) FROM tpcc${wares}.warehouse;"

echo "[Info] Complete to prepare and analyze tpcc${wares}, you can start to run benchmark."
sleep 60

###################################################################################################
# 执行 TPCC 测试
wares=1000
LIST="10 30 50 70 100"
for i in $LIST; do
  echo "[Info] Start to run tpcc test with ${i} threads."
  tiup bench tpcc run \
    --host ${tidb_host} --port 4000 \
    --db tpcc${wares} --warehouses ${wares} \
    --threads ${i} --time 1h \
    > result_summary_tpcc${wares}_threads_${i}.txt 2>&1

    sleep 60
done

tail -n 1 result_summary_tpcc*.txt > result_summary_tpcc${wares}_${INSTANCE_FAMILY}.txt
#################################################################################################################