# Dockerfile for Load Generation Tools
# Based on Amazon Linux 2023

FROM public.ecr.aws/amazonlinux/amazonlinux:2023

LABEL maintainer="your-email@example.com"
LABEL description="Load generation and benchmark tools for various databases and services"

# Set working directory
WORKDIR /root

# Install basic packages and development tools
RUN yum -yq groupinstall "Development Tools" && \
    yum -yq install \
        cmake \
        automake \
        autoconf \
        libtool \
        perl \
        perl-core \
        maven \
        python3.13 \
        python3.13-pip \
        java-17-amazon-corretto-devel \
        pcre-devel \
        zlib-devel \
        libmemcached-devel \
        libevent-devel \
        openssl-devel \
        libaio-devel \
        python3.13-devel \
        dnf-plugins-core \
        git \
        wget \
        tar \
        which \
        unzip \
        awscli \
        cloud-init \
        ec2-utils && \
    pip3.13 install dool && \
    yum clean all

# Install Terraform
RUN dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo && \
    yum install -yq terraform && \
    terraform --version && \
    yum clean all

# Install HammerDB 4.4 for MySQL benchmark
RUN cd /root && \
    wget -q https://github.com/TPC-Council/HammerDB/releases/download/v4.4/HammerDB-4.4-Linux.tar.gz && \
    tar zxf HammerDB-4.4-Linux.tar.gz && \
    rm -rf HammerDB-4.4-Linux.tar.gz && \
    rpm -Uvh https://repo.mysql.com//mysql80-community-release-el9.rpm && \
    yum install -y mysql mysql-server mysql-devel --nogpgcheck && \
    yum clean all

# Install memtier_benchmark for Redis/Valkey benchmark
RUN cd /root && \
    git clone https://github.com/RedisLabs/memtier_benchmark.git && \
    cd memtier_benchmark && \
    git checkout tags/2.0.0 && \
    autoreconf -ivf && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    memtier_benchmark --version && \
    cd /root && rm -rf memtier_benchmark

# Install Redis CLI for Redis/Valkey benchmark
RUN cd /root && \
    wget -q https://download.redis.io/releases/redis-7.2.4.tar.gz && \
    tar xzf redis-7.2.4.tar.gz && \
    cd redis-7.2.4 && \
    make -j$(nproc) && \
    make install && \
    redis-cli -v && \
    cd /root && rm -rf redis-7.2.4 redis-7.2.4.tar.gz

# Install sysbench
RUN cd /root && \
    wget -q https://github.com/akopytov/sysbench/archive/refs/tags/1.0.20.tar.gz && \
    tar zxf 1.0.20.tar.gz && \
    rm -rf 1.0.20.tar.gz && \
    cd sysbench-1.0.20 && \
    ./autogen.sh && \
    ./configure --with-mysql && \
    make -j$(nproc) && \
    make install && \
    sysbench --version && \
    cd /root && rm -rf sysbench-1.0.20

# Install wrk-4.2.0 for nginx/apisix benchmark
RUN cd /root && \
    wget -q https://github.com/wg/wrk/archive/refs/tags/4.2.0.tar.gz && \
    tar zxf 4.2.0.tar.gz && \
    rm -rf 4.2.0.tar.gz && \
    cd wrk-4.2.0 && \
    make -j$(nproc) && \
    cp wrk /usr/local/bin/ && \
    cd /root && rm -rf wrk-4.2.0

# Install YCSB-0.17.0 for MongoDB benchmark
RUN cd /root && \
    wget -q https://github.com/mongodb-js/mongosh/releases/download/v2.5.10/mongodb-mongosh-2.5.10.x86_64.rpm && \
    rpm -Uvh mongodb-mongosh-2.5.10.x86_64.rpm && \
    rm -f mongodb-mongosh-2.5.10.x86_64.rpm && \
    yum install -y python-is-python3 && \
    wget -q https://github.com/brianfrankcooper/YCSB/releases/download/0.17.0/ycsb-0.17.0.tar.gz && \
    tar zxf ycsb-0.17.0.tar.gz && \
    rm -rf ycsb-0.17.0.tar.gz && \
    yum clean all

# Install VDBBench for Milvus benchmark
RUN pip3.13 install vectordb-bench ujson

# Install Crank for .NET benchmark
RUN yum install -y git yq aspnetcore-runtime-8.0 dotnet-runtime-8.0 dotnet-sdk-8.0 && \
    dotnet tool install -g Microsoft.Crank.Controller --version "0.2.0-*" && \
    dotnet tool install -g Microsoft.Crank.Agent --version "0.2.0-*" && \
    yum clean all

# Add .NET tools to PATH
ENV PATH="${PATH}:/root/.dotnet/tools"

# Install JMeter
RUN cd /opt && \
    wget -q https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-5.6.3.tgz && \
    tar -xzf apache-jmeter-5.6.3.tgz && \
    rm -f apache-jmeter-5.6.3.tgz && \
    ln -s /opt/apache-jmeter-5.6.3 /opt/jmeter

# Add JMeter to PATH
ENV PATH="${PATH}:/opt/jmeter/bin"

# # Copy OS optimization script (if exists)
# COPY benchmark/os-optimization.sh /root/benchmark/os-optimization.sh 2>/dev/null || true

# # Run OS optimization if script exists
# RUN if [ -f /root/benchmark/os-optimization.sh ]; then \
#         bash /root/benchmark/os-optimization.sh; \
#     fi

# Verify installations
RUN echo "=== Verifying installations ===" && \
    terraform --version && \
    memtier_benchmark --version && \
    redis-cli -v && \
    sysbench --version && \
    python3.13 --version && \
    java -version && \
    echo "=== All tools installed successfully ==="

RUN mkdir -p /root/.aws /run/cloud-init /root/ec2-test-suite

# Set default command
CMD ["/bin/bash"]
