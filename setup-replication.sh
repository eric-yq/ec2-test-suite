#!/bin/bash

source /tmp/temp-setting
# cat /tmp/temp-setting

setup_redis_replicaton(){
	redis-cli -h ${INSTANCE_IP_SLAVE} slaveof ${INSTANCE_IP_MASTER} 6379
	sleep 10
	redis-cli -h ${INSTANCE_IP_SLAVE} info replication
}

setup_mysql_replicaton(){
	### master
	cat << EOF > setup_mysql_replication_master.sql
create user repl@'${INSTANCE_IP_SLAVE}' identified with mysql_native_password by 'DoNotChangeMe@@123';
grant replication slave on *.* to repl@'${INSTANCE_IP_SLAVE}';
flush privileges;
show master status\G;
EOF
	mysql -h ${INSTANCE_IP_MASTER} -uroot -p'gv2mysql' < setup_mysql_replication_master.sql
	
	### slave
	cat << EOF > setup_mysql_replication_slave.sql
change master to master_host='${INSTANCE_IP_MASTER}', \
master_user='repl', \
master_password='DoNotChangeMe@@123', \
MASTER_AUTO_POSITION=1;
start slave;
show slave status\G;
EOF
	mysql -h ${INSTANCE_IP_SLAVE} -uroot -p'gv2mysql' < setup_mysql_replication_slave.sql
}

setup_mongo_replication(){

	mongosh --host ${INSTANCE_IP_MASTER} --port 27017 -u root -p gv2mongo  << EOF
rs.initiate({
    _id: "rs0gv2mongo",
    members: [{
        _id: 0,
        host: "${INSTANCE_IP_MASTER}:27017"
    },{
        _id: 1,
        host: "${INSTANCE_IP_SLAVE}:27017"
    },{
        _id: 2,
        host: "${INSTANCE_IP_SLAVE1}:27017"
    }]
})
exit
EOF
	
	sleep 10
	
	## 查看副本集状态
	mongosh --host ${INSTANCE_IP_MASTER} --port 27017 -u root -p gv2mongo  << EOF
rs.status()
exit
EOF
}

## 主流程
echo "$0: Start to setup Cluster with master and slave."
echo "$0: IP address of master is ${INSTANCE_IP_MASTER}"
echo "$0: IP address of slave  is ${INSTANCE_IP_SLAVE}"
echo "$0: IP address of slave1 is ${INSTANCE_IP_SLAVE1}"

if   [[ "$SUT_NAME" == "redis-master-slave" ]] ; then

	setup_redis_replicaton
	
elif [[ "$SUT_NAME" == "mysql-master-slave" ]]; then

	setup_mysql_replicaton

elif [[ "$SUT_NAME" == "mongo-replicaset" ]]; then

	setup_mongo_replication

else
	echo "$0: No need to perform additional setup."
	exit 1
fi
