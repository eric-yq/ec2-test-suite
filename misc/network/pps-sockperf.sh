# 1. server side
## install sockperf
amazon-linux-extras install -y epel
yum install -y sockperf
## start server:
sockperf sr --tcp --daemonize
sar -n DEV 3

# 2. client side
## install sockperf
amazon-linux-extras install -y epel
yum install -y sockperf
## start to test
server_ip=172.31.6.92
msg_size=14
run_time=60
for i in $(seq 1 16)
do     
    nohup sockperf tp -i $server_ip --pps max -m ${msg_size} -t ${run_time} & 
done


######################################################################################
## servers
base_port=10000
threads=$(seq 1 $(nproc))
for i in $threads
do     
    sockperf sr --tcp --daemonize --port $[${base_port}+${i}] &
done
sar -n DEV 3

## client
server_ip=172.31.15.114
base_port=10000
threads=$(seq 1 $(nproc))
msg_size=14
run_time=10
for i in $threads
do     
    nohup sockperf tp -i $server_ip --pps max -m ${msg_size} -t ${run_time} --port $[${base_port}+${i}] 2>&1 &
done
