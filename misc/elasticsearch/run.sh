#!/bin/bash

bash  benchmark.sh  172.31.38.141 i8g.2xlarge
sleep 60

bash  benchmark.sh  172.31.45.2   i7ie.2xlarge
sleep 60

bash  benchmark.sh  172.31.41.71  i4i.2xlarge
sleep 60

bash  benchmark.sh  172.31.44.179 i4g.2xlarge
sleep 60

bash  benchmark.sh  172.31.47.75  i3.2xlarge
sleep 60