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

# 创建表
cmd_str='obclient -h%s -P%s -u%s@%s -p%s -D%s < create_tpch_mysql_table_part.ddl'%(hostname,port,user,tenant,password,db_name)
result = subprocess.run(cmd_str, shell=True, capture_output=True, text=True)
print(result.stdout)

cmd_str='obclient -h%s -P%s -u%s@%s -p%s  -D%s -e "show tables;" '%(hostname,port,user,tenant,password,db_name)
result = subprocess.run(cmd_str, shell=True, capture_output=True, text=True)
print(result.stdout)