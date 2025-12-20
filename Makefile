# Makefile for installing packages using yum

# Default target
.PHONY: all
all: install

# List of packages to install
PACKAGES = \
	cmake \
	maven \
	python3.13 \
	python3.13-pip

# List of additional packages for development tool
LIBRARIES = \
	java-17-amazon-corretto-devel \
	pcre-devel \
	zlib-devel \
	libmemcached-devel \
	libevent-devel \
	openssl-devel \
	libaio-devel \
	mariadb105-devel \
	python3.13-devel

# Install the required packages, libraries, and tools
# This target will be executed when you run 'make install'
# It will install development tools, Terraform, HammerDB, memtier_benchmark, sysbench
.PHONY: install
install:
	@echo "Installing some tools..."
	sudo yum -yq groupinstall "Development Tools"
	sudo yum -yq install $(PACKAGES)
	sudo yum -yq install $(LIBRARIES)
	sudo pip3.13 install dool
	@echo "Installation complete!"
	
	@echo "Installing Terraform..."
	sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
	sudo yum install -yq terraform
	terraform --version
	@echo "Terraform installation complete!"
	
	@echo "Installing HammerDB 4.4 for MySQL benchmark..."
	cd /root/ && \
	wget https://github.com/TPC-Council/HammerDB/releases/download/v4.4/HammerDB-4.4-Linux.tar.gz && \
	tar zxf HammerDB-4.4-Linux.tar.gz && \
	rm -rf HammerDB-4.4-Linux.tar.gz && \
	rpm -Uvh https://repo.mysql.com//mysql80-community-release-el9.rpm  && \
    yum install -y mysql mysql-server mysql-devel --nogpgcheck
	@echo "HammerDB installation complete!"
	
	@echo "Installing memtier_benchmark for Redis/Valky benchmark..."
	cd /root/ && \
	git clone https://github.com/RedisLabs/memtier_benchmark.git && \
	cd memtier_benchmark && \
	git checkout tags/2.0.0 && \
	autoreconf -ivf && \
	./configure && \
	make -j && \
	sudo make install && \
	memtier_benchmark --version
	@echo "memtier_benchmark installation complete!"

	@echo "Installing redis cli for Redis/Valky benchmark..."
	cd /root/  && \
	wget https://download.redis.io/releases/redis-7.2.4.tar.gz && \
	tar xzf redis-7.2.4.tar.gz && cd redis-7.2.4 && \
	make && make install  && \
	redis-cli -v && \
	@echo "redis cli installation complete!"
	
	@echo "Installing sysbench ..."
	cd /root/ && \
	wget https://github.com/akopytov/sysbench/archive/refs/tags/1.0.20.tar.gz && \
	tar zxf 1.0.20.tar.gz && rm -rf 1.0.20.tar.gz && \
	cd sysbench-1.0.20 && \
	./autogen.sh && \
	./configure && \
	make -j && \
	make install && \
	sysbench --version
	@echo "sysbench installation complete!"
	
	@echo "Installing wrk-4.2.0 for nginx/apisix benchmark ..."
	cd /root/ && \
	wget https://github.com/wg/wrk/archive/refs/tags/4.2.0.tar.gz && \
	tar zxf 4.2.0.tar.gz && rm -rf 4.2.0.tar.gz && \
	cd wrk-4.2.0 && \
	make -j
	@echo "wrk installation complete!"
	
	@echo "Installing YCSB-0.17.0 for MongoDB benchmark ..."
	cd /root/ && \
	wget https://github.com/mongodb-js/mongosh/releases/download/v2.5.10/mongodb-mongosh-2.5.10.x86_64.rpm && \
	rpm -Uvh mongodb-mongosh-2.5.10.x86_64.rpm && \
	wget https://github.com/brianfrankcooper/YCSB/releases/download/0.17.0/ycsb-0.17.0.tar.gz && \
	tar zxf ycsb-0.17.0.tar.gz && rm -rf ycsb-0.17.0.tar.gz
	@echo "YCSB installation complete!"

	@echo "Installing VDBBench for Milvus benchmark ..."
	cd /root/ && \
	pip3.11 install vectordb-bench ujson
	@echo "YCSB installation complete!"

# Clean yum cache
.PHONY: clean
clean:
	@echo "Cleaning yum cache..."
	sudo yum clean all
	@echo "Cache cleaned!"

# Show help
.PHONY: help
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  all        Install all packages (default)"
	@echo "  install    Install all required packages and benchmark tools"
	@echo "  clean      Clean yum cache"
	@echo "  help       Show this help message"
