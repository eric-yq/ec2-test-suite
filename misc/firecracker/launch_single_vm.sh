#!/bin/bash
# Script to launch a single Firecracker microVM with a random IP address
# For Ubuntu 24.04 on c7g.metal (ARM64)

set -e

# Create working directory
WORK_DIR="/root/firecracker-demo"
mkdir -p $WORK_DIR
cd $WORK_DIR

echo "Setting up resources for Firecracker microVM..."

# Download kernel and rootfs if not already present
if [ ! -f "$WORK_DIR/vmlinux" ]; then
    echo "Downloading kernel..."
    wget -O vmlinux https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/aarch64/kernels/vmlinux.bin
fi

if [ ! -f "$WORK_DIR/rootfs.ext4" ]; then
    echo "Downloading rootfs..."
    wget -O rootfs.ext4 https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/aarch64/rootfs/bionic.rootfs.ext4
fi

# Function to check if an IP address is already in use
is_ip_in_use() {
    local ip=$1
    ping -c 1 -W 1 $ip > /dev/null 2>&1
    return $?
}

# Function to generate a random IP address
get_random_ip() {
    local subnet="172.16"
    local third_octet=$((RANDOM % 254 + 1))
    local fourth_octet=$((RANDOM % 254 + 2)) # Avoid .0 (network) and .1 (gateway)
    echo "$subnet.$third_octet.$fourth_octet"
}

# Find an available IP address
find_available_ip() {
    local max_attempts=50
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        # Generate random IP components
        local third_octet=$((RANDOM % 254 + 1))
        local fourth_octet=1  # Gateway IP
        
        HOST_IP="172.16.$third_octet.$fourth_octet"
        GUEST_IP="172.16.$third_octet.2"  # VM IP
        THIRD_OCTET=$third_octet
        
        # Check if both IPs are available
        if ! is_ip_in_use $HOST_IP && ! is_ip_in_use $GUEST_IP; then
            echo "Found available IP pair: Host=$HOST_IP, Guest=$GUEST_IP"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo "Attempt $attempt: IP pair $HOST_IP/$GUEST_IP is in use, trying another..."
    done
    
    echo "Failed to find available IP address after $max_attempts attempts"
    return 1
}

# Find available IP addresses
find_available_ip
if [ $? -ne 0 ]; then
    echo "Error: Could not find available IP addresses. Exiting."
    exit 1
fi

# Use the third octet as VM ID for uniqueness
VM_ID=$THIRD_OCTET
TAP_NAME="fc-tap$VM_ID"

# Create tap device for networking
echo "Creating tap device $TAP_NAME with IP $HOST_IP/24..."
ip tuntap add dev $TAP_NAME mode tap
ip addr add $HOST_IP/24 dev $TAP_NAME
ip link set dev $TAP_NAME up

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Set up NAT
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $TAP_NAME -o eth0 -j ACCEPT

# Create VM configuration
SOCKET="$WORK_DIR/vm$VM_ID.sock"
LOG_FILE="$WORK_DIR/vm$VM_ID.log"
MAC_ADDR=$(printf "02:FC:00:00:%02X:%02X" $THIRD_OCTET 2)

cat > "$WORK_DIR/vm$VM_ID.json" << EOF
{
  "boot-source": {
    "kernel_image_path": "$WORK_DIR/vmlinux",
    "boot_args": "console=ttyS0 reboot=k panic=1 pci=off ip=$GUEST_IP::$HOST_IP:255.255.255.0::eth0:off"
  },
  "drives": [
    {
      "drive_id": "rootfs",
      "path_on_host": "$WORK_DIR/rootfs.ext4",
      "is_root_device": true,
      "is_read_only": false
    }
  ],
  "network-interfaces": [
    {
      "iface_id": "eth0",
      "guest_mac": "$MAC_ADDR",
      "host_dev_name": "$TAP_NAME"
    }
  ],
  "machine-config": {
    "vcpu_count": 1,
    "mem_size_mib": 256,
    "smt": false
  }
}
EOF

# Start the VM
echo "Starting VM with ID $VM_ID..."
firecracker --api-sock "$SOCKET" --config-file "$WORK_DIR/vm$VM_ID.json" > "$LOG_FILE" 2>&1 &

# Store the PID
PID=$!
echo $PID > "$WORK_DIR/vm$VM_ID.pid"

# Display VM information
sleep 3
echo "=== Firecracker VM Started ==="
echo "VM ID: $VM_ID"
echo "PID: $PID"
echo "Socket: $SOCKET"
echo "Guest IP: $GUEST_IP"
echo "Host IP (tap device): $HOST_IP"
echo "Tap device: $TAP_NAME"
echo "Log file: $LOG_FILE"

echo "=== Instructions ==="
echo "To connect to the VM, use: socat - UNIX-CONNECT:$SOCKET"
echo "To stop the VM, use: kill $PID"

