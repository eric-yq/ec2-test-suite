# AWS EC2 Benchmark Test Suite

In this repository there are some benchmark test suites for AWS EC2 instance.

## Prepare the EC2 instance

### 1. Launch an EC2 instance: 
- Instance type: such as `c6a.4xlarge`
- AMI:  `Amazon Linux 2023`
- Key Pair: `ericyq-global` 
    - if you use this keypair name, then you need not modify source code
    - or you need to modify the source code with your own key pair name.
    - upload keypair file `*.pem` to the path `/root` for some test cases.
- EBS configration: `80 GB gp3`
- Placement Group: `pg-cluster` with type `cluster`

### 2. Login with SSH session

### 3. Install Software Dependency and Test Tools
```bash
sudo su - root
yum update
yum install -yq make git
git clone https://github.com/eric-yq/ec2-test-suite
cd ec2-test-suite

# Install software pacakge, devel libararies and test tools for workload,
# Including: HammerDB, memtier_benchmark, wrk, ycsb and sysbench etc.
make all
```

### 4. Submit benchmark tests
Take redis benchmark for example:
```bash
cd ~/ec2-test-suite
cp samples-of-submit-benchmark/submit-benchmark-redis-test_v1.sh .
instance_types="r6i.2xlarge r7g.2xlarge"
```
Modify the value of `variable instance_types`, for example:
```bash
instance_types="r5.2xlarge r6a.2xlarge r6g.2xlarge r6i.2xlarge r7a.2xlarge r7g.2xlarge r7i.2xlarge r8g.2xlarge x8g.2xlarge"
```
Perform benchmark tests:
```bash
# screen -R ttt
bash submit-benchmark-redis-test_v1.sh
```
