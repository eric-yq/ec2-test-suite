#!/bin/bash

PASSWORD="GH7GM1wVfjUiMSmrpyFy"
TPCH_TEST="obclient -h 127.0.0.1 -P 2881 -uroot@sys -D oceanbase -p${PASSWORD} -c"

# warmup预热
for i in {1..22}
do
    sql1="source db${i}.sql"
    echo $sql1| $TPCH_TEST >db${i}.log || ret=1
done
# 正式执行
for i in {1..22}
do
    starttime=`date +%s%N`
    echo `date  '+[%Y-%m-%d %H:%M:%S]'` "BEGIN Q${i}"
    sql1="source db${i}.sql"
    echo $sql1| $TPCH_TEST >db${i}.log || ret=1
    stoptime=`date +%s%N`
    costtime=`echo $stoptime $starttime | awk '{printf "%0.2f\n", ($1 - $2) / 1000000000}'`
    echo `date  '+[%Y-%m-%d %H:%M:%S]'` "END,COST ${costtime}s"
done

## 单独执行某条SQL
# PASSWORD="GH7GM1wVfjUiMSmrpyFy"
# TPCH_TEST="obclient -h 127.0.0.1 -P 2881 -uroot@sys -D oceanbase -p${PASSWORD} -c" 
# sql="source db1.sql"
# echo $sql| $TPCH_TEST

