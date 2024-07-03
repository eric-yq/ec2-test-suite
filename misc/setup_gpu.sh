#!/bin/bash
set -e # Exit on any error

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

DOWNLOAD="wget"
USR_LOCAL_PREFIX="/usr/local"
CUDA_HOME=$USR_LOCAL_PREFIX/cuda
HOME_DIR=$HOME
SRC_DIR=$HOME_DIR/sources

CPUS=$(nproc)
LOG_FILE="$HOME_DIR/install.log"
LOCAL_TMP="$HOME_DIR/sources/local-tmp"
mkdir -p $LOCAL_TMP

if [[ "$1" != "--stdout" ]]; then
    exec >>"$LOG_FILE" 2>&1
fi
if lspci | grep -i "NVIDIA Corporation" >/dev/null; then
    echo "System has a GPU"
    HAS_GPU="true"
fi

# Create source directory
mkdir -p $SRC_DIR
pushd $SRC_DIR

# Helper functionS to check installation status
check_installation() {
    if [ -f "$1" ]; then
        echo "Success : $2 Installed"
    else
        echo "Error : $2 Installation Failed"
        echo "Exiting script due to installation failure."
        exit 1
    fi
}

# Helper function to check installation based on exit code
check_exit_code() {
    if [ $1 -eq 0 ]; then
        echo "Success : $2 Installed"
    else
        echo "Error : $2 Installation Failed (Exit Code: $1)"
        echo "Exiting script due to installation failure."
        exit 1
    fi
}

# Utility function to push a wildcard
pushdw() {
    pushd "$(find $HOME_DIR -type d -name "$1" | head -n 1)"
}

# Install system utilities and updates
install_utils() {
    if [ -n "$(command -v dnf)" ]; then
        package_manager="dnf"
    elif [ -n "$(command -v apt)" ]; then
        package_manager="apt"
    else
        echo "Neither DNF nor APT package manager found. Exiting."
        exit 1
    fi

    echo "Updating packages..."
    $package_manager -y update

    echo "Installing packages..."
    if [ "$package_manager" = "dnf" ]; then
        $package_manager -y groupinstall "Development Tools"
        $package_manager install -y git autoconf openssl-devel cmake3 htop iotop yasm nasm jq freetype-devel fribidi-devel harfbuzz-devel fontconfig-devel bzip2-devel
    elif [ "$package_manager" = "apt" ]; then
        export DEBIAN_FRONTEND=noninteractive;
        export NEEDRESTART_MODE=a;
        $package_manager install -y build-essential git autoconf libtool libssl-dev cmake htop iotop yasm nasm jq libfreetype6-dev libfribidi-dev libharfbuzz-dev libfontconfig1-dev libbz2-dev
    fi

    echo "Success: Updates and packages installed."

    echo "$USR_LOCAL_PREFIX/lib" | sudo tee /etc/ld.so.conf.d/usr-local-lib.conf
    echo "$USR_LOCAL_PREFIX/lib64" | sudo tee -a /etc/ld.so.conf.d/usr-local-lib.conf
    ldconfig
}

# Setup GPU, CUDA and CUDNN
setup_gpu() {
    if [ "$HAS_GPU" != "true" ]; then
        echo "Skipping GPU installation"
        return 0
    fi
    if [ "$(uname -m)" = "aarch64" ]; then
        echo "System is running on ARM / AArch64"
        DRIVE_URL="https://us.download.nvidia.com/tesla/535.104.05/NVIDIA-Linux-aarch64-535.104.05.run"
        CUDA_SDK_URL="https://developer.download.nvidia.com/compute/cuda/12.2.2/local_installers/cuda_12.2.2_535.104.05_linux_sbsa.run"
        CUDNN_ARCHIVE_URL="https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-sbsa/cudnn-linux-sbsa-8.9.5.29_cuda12-archive.tar.xz"
    else
        DRIVE_URL="https://us.download.nvidia.com/tesla/535.104.05/NVIDIA-Linux-x86_64-535.104.05.run"
        CUDA_SDK_URL="https://developer.download.nvidia.com/compute/cuda/12.2.2/local_installers/cuda_12.2.2_535.104.05_linux.run"
        CUDNN_ARCHIVE_URL="https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-8.9.5.29_cuda12-archive.tar.xz"
    fi

    echo "Setting up GPU..."
    DRIVER_NAME="NVIDIA-Linux-driver.run"
    wget -O "$DRIVER_NAME" "$DRIVE_URL"
    TMPDIR=$LOCAL_TMP sh "$DRIVER_NAME" --disable-nouveau --silent

    CUDA_SDK="cuda-linux.run"
    wget -O "$CUDA_SDK" "$CUDA_SDK_URL"
    TMPDIR=$LOCAL_TMP sh "$CUDA_SDK" --silent --override --toolkit --samples --toolkitpath=$USR_LOCAL_PREFIX/cuda-12.2 --samplespath=$CUDA_HOME --no-opengl-libs

    CUDNN_ARCHIVE="cudnn-linux.tar.xz"
    EXTRACT_PATH="$SRC_DIR/cudnn-extracted"
    mkdir -p "$EXTRACT_PATH"

    wget -O "$CUDNN_ARCHIVE" "$CUDNN_ARCHIVE_URL"
    tar -xJf "$CUDNN_ARCHIVE" -C "$EXTRACT_PATH"
    CUDNN_INCLUDE=$(find "$EXTRACT_PATH" -type d -name "include" -print -quit)
    CUDNN_LIB=$(find "$EXTRACT_PATH" -type d -name "lib" -print -quit)
    cp -P "$CUDNN_INCLUDE"/* $CUDA_HOME/include/
    cp -P "$CUDNN_LIB"/* $CUDA_HOME/lib64/
    chmod a+r $CUDA_HOME/lib64/*
    ldconfig
    rm -fr cu* NVIDIA*
}


# Execute Functions
install_utils
setup_gpu
source $HOME_DIR/.bashrc
popd
rm -fr $SRC_DIR
