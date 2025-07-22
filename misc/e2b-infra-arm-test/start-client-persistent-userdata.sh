#!/usr/bin/env bash

# This script is meant to be run in the User Data of each EC2 Instance while it's booting. The script uses the
# run-nomad and run-consul scripts to configure and start Nomad and Consul in client mode. Note that this script
# assumes it's running in an AMI built from the Packer template in examples/nomad-consul-ami/nomad-consul.json.

set -euo pipefail

# Set timestamp format
PS4='[\D{%Y-%m-%d %H:%M:%S}] '
# Enable command tracing
set -x

# Send the log output from this script to user-data.log, syslog, and the console
# Inspired by https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

# Add cache disk for orchestrator and swapfile
# For AWS EBS volumes, typically the device will be /dev/nvme1n1 or similar
DISK="/dev/nvme1n1"
MOUNT_POINT="/orchestrator"

# Check for NVMe device (AWS uses NVMe)
if [ ! -e "$DISK" ]; then
    # Find the first attached EBS volume that's not the root volume
    DISK=$(lsblk -o NAME,TYPE -n | grep -v 'part\|lvm' | grep -v "$(df -h / | tail -1 | awk '{print $1}' | sed 's/\/dev\///')" | head -1 | awk '{print "/dev/"$1}')
fi

# Step 1: Format the disk with XFS and standard block size
sudo mkfs.xfs -f -b size=4096 $DISK

# Step 2: Create the mount point
sudo mkdir -p $MOUNT_POINT

# Step 3: Mount the disk
sudo mount -o noatime $DISK $MOUNT_POINT

# Make the orchestrator disk mount persistent
echo "$DISK $MOUNT_POINT xfs defaults,noatime 0 2" | sudo tee -a /etc/fstab

sudo mkdir -p /orchestrator/sandbox
sudo mkdir -p /orchestrator/template
sudo mkdir -p /orchestrator/build

# Add swapfile
SWAPFILE="/swapfile"
sudo fallocate -l 100G $SWAPFILE
sudo chmod 600 $SWAPFILE
sudo mkswap $SWAPFILE
sudo swapon $SWAPFILE

# Make swapfile persistent (this was already in your original script)
echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab

# Add tmpfs for snapshotting
sudo mkdir -p /mnt/snapshot-cache
sudo mount -t tmpfs -o size=65G tmpfs /mnt/snapshot-cache

# Make tmpfs mount persistent
echo "tmpfs /mnt/snapshot-cache tmpfs size=65G 0 0" | sudo tee -a /etc/fstab

ulimit -n 1048576
export GOMAXPROCS='nproc'

# Use /etc/sysctl.d/ for better organization and persistence
sudo tee /etc/sysctl.d/99-custom.conf <<EOF
# Increase the maximum number of socket connections
net.core.somaxconn = 65535

# Increase the maximum number of backlogged connections
net.core.netdev_max_backlog = 65535

# Increase maximum number of TCP sockets
net.ipv4.tcp_max_syn_backlog = 65535

# Increase the maximum number of memory map areas
vm.max_map_count = 1048576

# Set swap settings
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOF

# Apply sysctl settings immediately
sudo sysctl -p /etc/sysctl.d/99-custom.conf

echo "Disabling inotify for NBD devices"
# https://lore.kernel.org/lkml/20220422054224.19527-1-matthew.ruffell@canonical.com/
sudo tee /etc/udev/rules.d/97-nbd-device.rules <<EOH
# Disable inotify watching of change events for NBD devices
ACTION=="add|change", KERNEL=="nbd*", OPTIONS:="nowatch"
EOH

sudo udevadm control --reload-rules
sudo udevadm trigger

# Make NBD module loading persistent
echo "nbd" | sudo tee -a /etc/modules-load.d/nbd.conf
echo "options nbd nbds_max=4096" | sudo tee -a /etc/modprobe.d/nbd.conf

# Load the nbd module with 4096 devices (for current session)
sudo modprobe nbd nbds_max=4096

# Create the directory for the fc mounts
mkdir -p /fc-vm

# Create the mount points for S3 buckets
envd_dir="/fc-envd"
mkdir -p $envd_dir

kernels_dir="/fc-kernels"
mkdir -p $kernels_dir

fc_versions_dir="/fc-versions"
mkdir -p $fc_versions_dir

# Install s3fs-fuse if not already installed
if ! command -v s3fs &>/dev/null; then
    apt-get update && apt-get install -y s3fs
fi

# Create cache directories for s3fs
sudo mkdir -p /tmp/s3fs_cache_kernels
sudo mkdir -p /tmp/s3fs_cache_versions

# Mount S3 buckets using s3fs
s3fs ${FC_ENV_PIPELINE_BUCKET_NAME} $envd_dir -o iam_role=auto,allow_other,ro,umask=0022
s3fs ${FC_KERNELS_BUCKET_NAME} $kernels_dir -o iam_role=auto,allow_other,ro,umask=0022,use_cache=/tmp/s3fs_cache_kernels
s3fs ${FC_VERSIONS_BUCKET_NAME} $fc_versions_dir -o iam_role=auto,allow_other,ro,umask=0022,use_cache=/tmp/s3fs_cache_versions

# Make S3 mounts persistent in fstab
echo "${FC_ENV_PIPELINE_BUCKET_NAME} $envd_dir fuse.s3fs _netdev,iam_role=auto,allow_other,ro,umask=0022 0 0" | sudo tee -a /etc/fstab
echo "${FC_KERNELS_BUCKET_NAME} $kernels_dir fuse.s3fs _netdev,iam_role=auto,allow_other,ro,umask=0022,use_cache=/tmp/s3fs_cache_kernels 0 0" | sudo tee -a /etc/fstab
echo "${FC_VERSIONS_BUCKET_NAME} $fc_versions_dir fuse.s3fs _netdev,iam_role=auto,allow_other,ro,umask=0022,use_cache=/tmp/s3fs_cache_versions 0 0" | sudo tee -a /etc/fstab

# These variables are passed in via Terraform template interpolation
aws s3 cp "s3://${SCRIPTS_BUCKET}/run-consul-${RUN_CONSUL_FILE_HASH}.sh" /opt/consul/bin/run-consul.sh
aws s3 cp "s3://${SCRIPTS_BUCKET}/run-nomad-${RUN_NOMAD_FILE_HASH}.sh" /opt/nomad/bin/run-nomad.sh

chmod +x /opt/consul/bin/run-consul.sh /opt/nomad/bin/run-nomad.sh

mkdir -p /root/docker
touch /root/docker/config.json
# export ECR_AUTH_TOKEN=$(aws ecr get-authorization-token --output text --query 'authorizationData[].authorizationToken')
cat <<EOF >/root/docker/config.json
{
    "auths": {
        "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com": {
            "auth": "$(aws ecr get-authorization-token --output text --query 'authorizationData[].authorizationToken')"
        }
    }
}
EOF

mkdir -p /etc/systemd/resolved.conf.d/
touch /etc/systemd/resolved.conf.d/consul.conf
cat <<EOF >/etc/systemd/resolved.conf.d/consul.conf
[Resolve]
DNS=127.0.0.1:8600
DNSSEC=false
Domains=~consul
EOF
systemctl restart systemd-resolved

# Set up huge pages
# We are not enabling Transparent Huge Pages for now, as they are not swappable and may result in slowdowns + we are not using swap right now.
# The THP are by default set to madvise
# We are allocating the hugepages at the start when the memory is not fragmented yet
echo "[Setting up huge pages]"
sudo mkdir -p /mnt/hugepages
mount -t hugetlbfs none /mnt/hugepages

# Make hugepages mount persistent
echo "none /mnt/hugepages hugetlbfs defaults 0 0" | sudo tee -a /etc/fstab

# Increase proactive compaction to reduce memory fragmentation for using overcomitted huge pages

available_ram=$(grep MemTotal /proc/meminfo | awk '{print $2}') # in KiB
available_ram=$(($available_ram / 1024))                        # in MiB
echo "- Total memory: $available_ram MiB"

min_normal_ram=$((4 * 1024))                             # 4 GiB
min_normal_percentage_ram=$(($available_ram * 16 / 100)) # 16% of the total memory
max_normal_ram=$((42 * 1024))                            # 42 GiB

max() {
    if (($1 > $2)); then
        echo "$1"
    else
        echo "$2"
    fi
}

min() {
    if (($1 < $2)); then
        echo "$1"
    else
        echo "$2"
    fi
}

ensure_even() {
    if (($1 % 2 == 0)); then
        echo "$1"
    else
        echo $(($1 - 1))
    fi
}

remove_decimal() {
    echo "$(echo $1 | sed 's/\..*//')"
}

reserved_normal_ram=$(max $min_normal_ram $min_normal_percentage_ram)
reserved_normal_ram=$(min $reserved_normal_ram $max_normal_ram)
echo "- Reserved RAM: $reserved_normal_ram MiB"

# The huge pages RAM should still be usable for normal pages in most cases.
hugepages_ram=$(($available_ram - $reserved_normal_ram))
hugepages_ram=$(remove_decimal $hugepages_ram)
hugepages_ram=$(ensure_even $hugepages_ram)
echo "- RAM for hugepages: $hugepages_ram MiB"

hugepage_size_in_mib=2
echo "- Huge page size: $hugepage_size_in_mib MiB"
hugepages=$(($hugepages_ram / $hugepage_size_in_mib))

# This percentage will be permanently allocated for huge pages and in monitoring it will be shown as used.
base_hugepages_percentage=20
base_hugepages=$(($hugepages * $base_hugepages_percentage / 100))
base_hugepages=$(remove_decimal $base_hugepages)
echo "- Allocating $base_hugepages huge pages ($base_hugepages_percentage%) for base usage"
echo $base_hugepages >/proc/sys/vm/nr_hugepages

overcommitment_hugepages_percentage=$((100 - $base_hugepages_percentage))
overcommitment_hugepages=$(($hugepages * $overcommitment_hugepages_percentage / 100))
overcommitment_hugepages=$(remove_decimal $overcommitment_hugepages)
echo "- Allocating $overcommitment_hugepages huge pages ($overcommitment_hugepages_percentage%) for overcommitment"
echo $overcommitment_hugepages >/proc/sys/vm/nr_overcommit_hugepages

# Create systemd service for hugepages setup to persist across reboots
sudo tee /etc/systemd/system/setup-hugepages.service <<EOF
[Unit]
Description=Setup Hugepages
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo $base_hugepages > /proc/sys/vm/nr_hugepages; echo $overcommitment_hugepages > /proc/sys/vm/nr_overcommit_hugepages'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable the hugepages service
sudo systemctl enable setup-hugepages.service

# Create systemd service to recreate s3fs cache directories on boot
sudo tee /etc/systemd/system/setup-s3fs-cache.service <<EOF
[Unit]
Description=Setup S3FS Cache Directories
Before=remote-fs.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'mkdir -p /tmp/s3fs_cache_kernels /tmp/s3fs_cache_versions'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable the s3fs cache setup service
sudo systemctl enable setup-s3fs-cache.service

# Make ulimit settings persistent by adding to /etc/security/limits.conf
echo "* soft nofile 1048576" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 1048576" | sudo tee -a /etc/security/limits.conf

# These variables are passed in via Terraform template interpolation
/opt/consul/bin/run-consul.sh --client \
    --consul-token "${CONSUL_TOKEN}" \
    --cluster-tag-name "${CLUSTER_TAG_NAME}" \
    --enable-gossip-encryption \
    --gossip-encryption-key "${CONSUL_GOSSIP_ENCRYPTION_KEY}" \
    --dns-request-token "${CONSUL_DNS_REQUEST_TOKEN}" &

/opt/nomad/bin/run-nomad.sh --client --consul-token "${CONSUL_TOKEN}" &

# Add alias for ssh-ing to sbx - make it persistent in /etc/profile
sudo tee -a /etc/profile <<'EOF'

# Custom aliases and functions
_sbx_ssh() {
  local address=$(dig @127.0.0.4 $1. A +short 2>/dev/null)
  ssh -o StrictHostKeyChecking=accept-new "root@$address"
}

alias sbx-ssh=_sbx_ssh
EOF

echo "Script execution completed. All configurations should persist across reboots."
