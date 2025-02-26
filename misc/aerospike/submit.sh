#!/bin/bash 

## test on 16xlarge
bash run.sh i8g.16xlarge  3 test_2K_100M
bash run.sh i4g.16xlarge  3 test_2K_100M
bash run.sh i4i.16xlarge  3 test_2K_100M
bash run.sh i3.16xlarge   3 test_2K_100M
bash run.sh r6id.16xlarge 3 test_2K_100M
bash run.sh r7gd.16xlarge 3 test_2K_100M
