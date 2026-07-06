#!/bin/bash
###############################################################################
# NVMe Instance Store — LVM Stripe + XFS 性能最大化配置脚本（可重入/幂等）
# 适用于：Amazon Linux 2023 / Ubuntu 22.04+ 上带有 NVMe Instance Store 的实例
# 用途：将所有 Instance Store NVMe 盘合并为 LVM Stripe，XFS 格式化并以最优参数挂载
#
# 设计原则：
#   - 可重入（Idempotent）：多次执行结果相同，已完成的步骤自动跳过
#   - 每步先检查状态，再决定是否执行
#   - 安全退出：不会破坏已有的有效配置
###############################################################################

set -euo pipefail

# ========================= 配置区 =========================
MOUNT_POINT="/data"
VG_NAME="data_vg"
LV_NAME="data_lv"
LV_PATH="/dev/${VG_NAME}/${LV_NAME}"
STRIPE_SIZE="256k"          # LVM stripe unit = XFS su（大 I/O 场景可改为 1024k）
XFS_LOG_SIZE="256m"         # XFS 日志大小
READAHEAD_SECTORS=2048      # 预读扇区数（2048 × 512B = 1MB）
MOUNT_OPTS="noatime,nodiratime,logbufs=8,logbsize=256k,allocsize=1g"
# ===========================================================

echo "=========================================="
echo " NVMe Instance Store 性能优化配置脚本"
echo " （可重入模式 — 已完成的步骤自动跳过）"
echo "=========================================="

# ---------- 1. 安装依赖 ----------
echo "[1/8] 检查依赖包..."
NEED_INSTALL=0
for cmd in pvcreate nvme xfs_info; do
    if ! command -v "$cmd" &>/dev/null; then
        NEED_INSTALL=1
        break
    fi
done

if [[ $NEED_INSTALL -eq 1 ]]; then
    echo "  安装依赖..."
    if command -v dnf &>/dev/null; then
        sudo dnf install -y lvm2 nvme-cli xfsprogs util-linux
    elif command -v apt-get &>/dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y lvm2 nvme-cli xfsprogs util-linux
    else
        echo "ERROR: 不支持的包管理器" >&2
        exit 1
    fi
else
    echo "  ✓ 依赖已就绪，跳过安装"
fi

# ---------- 2. 发现 NVMe Instance Store 盘 ----------
echo "[2/8] 发现 NVMe Instance Store 盘..."
mapfile -t DISKS < <(sudo nvme list 2>/dev/null \
    | grep -i "Instance Storage\|Amazon EC2 NVMe Instance Storage" \
    | awk '{print $1}')

# 备用检测：通过 lsblk model 字段
if [[ ${#DISKS[@]} -eq 0 ]]; then
    mapfile -t DISKS < <(lsblk -dno NAME,MODEL \
        | grep -i "Instance Storage" \
        | awk '{print "/dev/"$1}')
fi

NUM_DISKS=${#DISKS[@]}

if [[ $NUM_DISKS -eq 0 ]]; then
    echo "ERROR: 未发现 NVMe Instance Store 盘，退出。" >&2
    exit 1
fi

echo "  发现 ${NUM_DISKS} 块盘: ${DISKS[*]}"

# ---------- 3. 创建 LVM ----------
echo "[3/8] 检查 LVM（PV → VG → Stripe LV）..."

if sudo lvs "$LV_PATH" &>/dev/null; then
    echo "  ✓ LV $LV_PATH 已存在，跳过 LVM 创建"
else
    echo "  创建 LVM..."
    # 如果 VG 存在但 LV 不存在（异常状态），先清理
    if sudo vgs "$VG_NAME" &>/dev/null; then
        echo "  清理残留 VG..."
        sudo vgremove -f "$VG_NAME" 2>/dev/null || true
    fi

    # 清理盘上可能存在的残留签名
    for d in "${DISKS[@]}"; do
        sudo wipefs -af "$d" 2>/dev/null || true
        sudo pvremove -f "$d" 2>/dev/null || true
    done

    sudo pvcreate -f "${DISKS[@]}"
    sudo vgcreate "$VG_NAME" "${DISKS[@]}"
    sudo lvcreate -y -l 100%FREE \
        -i "$NUM_DISKS" \
        -I "$STRIPE_SIZE" \
        -n "$LV_NAME" \
        "$VG_NAME"
    echo "  LV 创建完成: $LV_PATH"
fi

# 确保 VG 已激活
sudo vgchange -ay "$VG_NAME" 2>/dev/null || true

# ---------- 4. 格式化 XFS ----------
echo "[4/8] 检查文件系统..."

if sudo xfs_info "$LV_PATH" &>/dev/null 2>&1; then
    echo "  ✓ XFS 文件系统已存在，跳过格式化"
else
    echo "  格式化 XFS（性能最大化参数）..."
    sudo mkfs.xfs -f \
        -d su="${STRIPE_SIZE}",sw="${NUM_DISKS}" \
        -l size="${XFS_LOG_SIZE}",su="${STRIPE_SIZE}",lazy-count=1 \
        -i size=512 \
        -b size=4096 \
        "$LV_PATH"
    echo "  格式化完成"
fi

# ---------- 5. 挂载 ----------
echo "[5/8] 检查挂载..."

if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    echo "  ✓ ${MOUNT_POINT} 已挂载，跳过"
else
    echo "  挂载到 ${MOUNT_POINT}..."
    sudo mkdir -p "$MOUNT_POINT"
    sudo mount -o "$MOUNT_OPTS" "$LV_PATH" "$MOUNT_POINT"
    echo "  挂载成功: $(df -h "$MOUNT_POINT" | tail -1)"
fi

# ---------- 6. 系统层面 I/O 调优 ----------
echo "[6/8] 系统 I/O 调优..."
for d in "${DISKS[@]}"; do
    DEV_NAME=$(basename "$d")

    # I/O 调度器 → none
    SCHED_PATH="/sys/block/${DEV_NAME}/queue/scheduler"
    if [[ -f "$SCHED_PATH" ]]; then
        CURRENT_SCHED=$(cat "$SCHED_PATH" | grep -oP '\[\K[^\]]+')
        if [[ "$CURRENT_SCHED" != "none" ]]; then
            echo none | sudo tee "$SCHED_PATH" >/dev/null
        fi
    fi

    # 预读
    CURRENT_RA=$(sudo blockdev --getra "$d" 2>/dev/null || echo 0)
    if [[ "$CURRENT_RA" -ne "$READAHEAD_SECTORS" ]]; then
        sudo blockdev --setra "$READAHEAD_SECTORS" "$d"
    fi

    # 队列深度
    NR_REQ_PATH="/sys/block/${DEV_NAME}/queue/nr_requests"
    if [[ -f "$NR_REQ_PATH" ]]; then
        CURRENT_NR=$(cat "$NR_REQ_PATH")
        if [[ "$CURRENT_NR" -ne 1024 ]]; then
            echo 1024 | sudo tee "$NR_REQ_PATH" >/dev/null 2>&1 || true
        fi
    fi

    # 关闭合并
    NOMERGES_PATH="/sys/block/${DEV_NAME}/queue/nomerges"
    if [[ -f "$NOMERGES_PATH" ]]; then
        CURRENT_NM=$(cat "$NOMERGES_PATH")
        if [[ "$CURRENT_NM" -ne 2 ]]; then
            echo 2 | sudo tee "$NOMERGES_PATH" >/dev/null
        fi
    fi
done
echo "  ✓ I/O 调优已应用"

# 内核参数优化（sysctl 本身是幂等的）
sudo sysctl -w vm.dirty_ratio=40 >/dev/null
sudo sysctl -w vm.dirty_background_ratio=10 >/dev/null
sudo sysctl -w vm.dirty_expire_centisecs=3000 >/dev/null
sudo sysctl -w vm.dirty_writeback_centisecs=500 >/dev/null

# ---------- 7. 验证 ----------
echo "[7/8] 配置验证..."
echo ""
echo "=================== 最终状态 ==================="
echo "LVM 信息:"
sudo lvs "$LV_PATH" -o lv_name,vg_name,lv_size,stripes,stripe_size
echo ""
echo "XFS 信息:"
sudo xfs_info "$MOUNT_POINT" | grep -E "data|log|naming"
echo ""
echo "挂载信息:"
mount | grep "$MOUNT_POINT"
echo ""
echo "磁盘空间:"
df -h "$MOUNT_POINT"
echo ""
echo "I/O 调度器:"
for d in "${DISKS[@]}"; do
    DEV=$(basename "$d")
    echo "  $DEV: $(cat /sys/block/$DEV/queue/scheduler 2>/dev/null || echo 'N/A')"
done
echo ""
echo "================================================="

# ---------- 8. 安装 systemd service（reboot 后自动恢复） ----------
echo "[8/8] 检查 systemd service..."

SERVICE_FILE="/etc/systemd/system/nvme-instance-store.service"
UDEV_RULE="/etc/udev/rules.d/99-nvme-instance-store-tuning.rules"
SCRIPT_PATH="$(realpath "$0")"

if [[ -f "$SERVICE_FILE" ]] && systemctl is-enabled nvme-instance-store.service &>/dev/null; then
    echo "  ✓ systemd service 已存在且已启用，跳过"
else
    echo "  安装 systemd service..."
    sudo tee "$SERVICE_FILE" >/dev/null <<EOF
[Unit]
Description=NVMe Instance Store — LVM activate + XFS mount
After=local-fs.target lvm2-activation.service
Wants=lvm2-activation.service
Before=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes

# 尝试激活已有 VG（reboot 场景），失败则完整重建（stop→start 场景）
ExecStart=/bin/bash -c '\
    if vgs ${VG_NAME} &>/dev/null; then \
        echo "VG ${VG_NAME} 存在，直接激活并挂载..."; \
        vgchange -ay ${VG_NAME} && \
        mkdir -p ${MOUNT_POINT} && \
        mount -o ${MOUNT_OPTS} /dev/${VG_NAME}/${LV_NAME} ${MOUNT_POINT}; \
    else \
        echo "VG ${VG_NAME} 不存在，执行完整初始化脚本..."; \
        ${SCRIPT_PATH}; \
    fi'

ExecStop=/bin/bash -c '\
    umount ${MOUNT_POINT} 2>/dev/null || true; \
    vgchange -an ${VG_NAME} 2>/dev/null || true'

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable nvme-instance-store.service
    echo "  ✓ systemd service 已安装并启用"
fi

if [[ -f "$UDEV_RULE" ]]; then
    echo "  ✓ udev 规则已存在，跳过"
else
    echo "  安装 udev 规则..."
    sudo tee "$UDEV_RULE" >/dev/null <<'EOF'
# NVMe Instance Store I/O 调优
ACTION=="add|change", KERNEL=="nvme*n1", SUBSYSTEM=="block", ATTR{model}=="Amazon EC2 NVMe Instance Storage*", \
    RUN+="/bin/sh -c 'echo none > /sys/block/%k/queue/scheduler; echo 2048 > /sys/block/%k/queue/read_ahead_kb; echo 1024 > /sys/block/%k/queue/nr_requests; echo 2 > /sys/block/%k/queue/nomerges'"
EOF
    sudo udevadm control --reload-rules
    echo "  ✓ udev 规则已安装"
fi

echo ""
echo "================================================="
echo "✅ 配置完成！挂载点: ${MOUNT_POINT}"
echo ""
echo "提示:"
echo "  - Instance Store 为临时存储，stop/terminate 后数据丢失"
echo "  - ✅ 已安装 systemd service，reboot 后自动激活 LVM 并挂载"
echo "  - ✅ 已安装 udev 规则，I/O 调优在盘出现时自动应用"
echo "  - Reboot：数据保留，service 自动激活 + 挂载（无需手动操作）"
echo "  - Stop→Start：数据丢失，service 自动检测并重新执行完整初始化"
echo "  - 本脚本可重入，重复执行安全无副作用"
echo "  - 查看服务状态: systemctl status nvme-instance-store"
echo "  - 查看日志: journalctl -u nvme-instance-store"
echo "================================================="