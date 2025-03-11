#!/bin/bash

for i in $(seq 1 3)
do
	SUT_IP_ADDR="172.31.6.211"
	SUT_INSTYPE="r6i.4xlarge"
	bash valkey-benchmark_shein-pg-partition.sh $SUT_IP_ADDR $SUT_INSTYPE

	SUT_IP_ADDR="172.31.9.35"
	SUT_INSTYPE="r7g.4xlarge"
	bash valkey-benchmark_shein-pg-partition.sh $SUT_IP_ADDR $SUT_INSTYPE

	SUT_IP_ADDR="172.31.5.248"
	SUT_INSTYPE="r8g.4xlarge"
	bash valkey-benchmark_shein-pg-partition.sh $SUT_IP_ADDR $SUT_INSTYPE

	SUT_IP_ADDR="172.31.11.78"
	SUT_INSTYPE="r6g.4xlarge"
	bash valkey-benchmark_shein-pg-partition.sh $SUT_IP_ADDR $SUT_INSTYPE
done


