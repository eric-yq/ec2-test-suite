#!/usr/bin/env python
#-*- encoding:utf-8 -*-
import os
import sys
import time
import subprocess

hostname='127.0.0.1'  # OceanBase数据库链接地址
port='2881'           #端口号
user='root'           # 用户名
tenant='sys'
password='xxxxxxxxx'  # 密码
data_path='/root/TPC-H_Tools_v3.0.0/dbgen/tpch50' # 注意！！请填写压力机ECS下 tbl 所在目录
db_name='oceanbase'   # 数据库名

# 加载数据
cmd_str=""" obclient -h%s -P%s -u%s@%s -p%s -c  -D%s -e "load data /*+ parallel(80) */ local infile '%s/customer.tbl' into table customer fields terminated by '|';" """ %(hostname,port,user,tenant,password,db_name,data_path)
result = subprocess.run(cmd_str, shell=True, capture_output=True, text=True)
print(result.stdout)

cmd_str=""" obclient -h%s -P%s -u%s@%s -p%s -c  -D%s -e "load data /*+ parallel(80) */ local infile '%s/lineitem.tbl' into table lineitem fields terminated by '|';" """ %(hostname,port,user,tenant,password,db_name,data_path)
result = subprocess.run(cmd_str, shell=True, capture_output=True, text=True)
print(result.stdout)

cmd_str=""" obclient -h%s -P%s -u%s@%s -p%s -c -D%s -e "load data /*+ parallel(80) */ local infile '%s/nation.tbl' into table nation fields terminated by '|';" """ %(hostname,port,user,tenant,password,db_name,data_path)
result = subprocess.run(cmd_str, shell=True, capture_output=True, text=True)
print(result.stdout)

cmd_str=""" obclient -h%s -P%s -u%s@%s -p%s -c  -D%s -e "load data /*+ parallel(80) */ local infile '%s/orders.tbl' into table orders fields terminated by '|';" """ %(hostname,port,user,tenant,password,db_name,data_path)
result = subprocess.run(cmd_str, shell=True, capture_output=True, text=True)
print(result.stdout)

cmd_str=""" obclient -h%s -P%s -u%s@%s -p%s   -D%s -e "load data /*+ parallel(80) */ local infile '%s/partsupp.tbl' into table partsupp fields terminated by '|';" """ %(hostname,port,user,tenant,password,db_name,data_path)
result = subprocess.run(cmd_str, shell=True, capture_output=True, text=True)
print(result.stdout)

cmd_str=""" obclient -h%s -P%s -u%s@%s -p%s -c  -D%s -e "load data /*+ parallel(80) */ local infile '%s/part.tbl' into table part fields terminated by '|';" """ %(hostname,port,user,tenant,password,db_name,data_path)
result = subprocess.run(cmd_str, shell=True, capture_output=True, text=True)
print(result.stdout)

cmd_str=""" obclient -h%s -P%s -u%s@%s -p%s -c  -D%s -e "load data /*+ parallel(80) */ local infile '%s/region.tbl' into table region fields terminated by '|';" """ %(hostname,port,user,tenant,password,db_name,data_path)
result = subprocess.run(cmd_str, shell=True, capture_output=True, text=True)
print(result.stdout)

cmd_str=""" obclient -h%s -P%s -u%s@%s -p%s -c  -D%s -e "load data /*+ parallel(80) */ local infile '%s/supplier.tbl' into table supplier fields terminated by '|';" """ %(hostname,port,user,tenant,password,db_name,data_path)
result = subprocess.run(cmd_str, shell=True, capture_output=True, text=True)
print(result.stdout)