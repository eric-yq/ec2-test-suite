# EC2 Benchmark 工作流

## 背景
Eric 的日常工作是对 AWS EC2 实例进行性能基准测试，对比 Graviton 各代实例与 x86 架构实例在主流开源软件上的性能差异。

典型测试场景示例：对比 r8g.2xlarge、r7g.2xlarge、r8i.2xlarge、r7i.2xlarge、r6i.2xlarge 在 Redis benchmark 中的表现。

## 基础设施

### Benchmark 管理平台
- 实例名称：loadgen-seed（长期运行）
- 公网 IP：54.221.55.45
- 登录方式：`ssh -i ~/.ssh/ericyq-global.pem ec2-user@54.221.55.45`
- 代码库路径：~/ec2-test-suite（通过 git pull 更新）
- 自动化工具：Terraform + Shell 脚本
- 已安装工具：memtier_benchmark, ycsb, wrk, hammerdb, dool 等

### 角色说明
- **Loadgen 实例**：负责发起 benchmark 流量（每次测试临时创建，**每个 SUT 对应一个独立的 Loadgen**）
- **SUT (System Under Test) 实例**：被测目标实例（由 `submit-benchmark-*.sh` 脚本自动创建，无需手动 launch）

### Benchmark 类型分类

| 类型 | 说明 | 需要 Loadgen | 脚本 | Workload 示例 |
|------|------|-------------|------|--------------|
| **Client-Server 型** | 需要 Loadgen 实例向 SUT 发送测试流量 | ✅ 是 | `submit-benchmark-<workload>.sh` | redis, valkey, mongo, mysql-hammerdb, nginx, milvus |
| **Single 型** | SUT 单机即可完成，无需外部流量 | ❌ 否 | `submit-benchmark-singles.sh` | specjbb15, ffmpeg, spark, pts |

## Client-Server 型 Benchmark 操作流程

适用于 redis, valkey, mongo, mysql-hammerdb, nginx, milvus 等需要 Loadgen 发送流量的 workload。

### Step 1: 更新代码库（在管理平台上）
```bash
ssh -i ~/.ssh/ericyq-global.pem ec2-user@54.221.55.45
sudo su - root
cd ~/ec2-test-suite && git pull
```

### Step 2: 创建 Loadgen 实例
```bash
USE_CPG=1 bash launch-instances-single.sh -s loadgen -t <实例类型>
```
- 记录输出的公网 IP
- **每个 SUT 创建一个独立的 Loadgen**（如测 r8g + r7i，则创建 2 个 Loadgen）
- 参数说明：
  - `-s loadgen`：指定实例角色为 loadgen
  - `-t <实例类型>`：指定 loadgen 的实例类型
  - `USE_CPG=1`：将 SUT 实例放入与 Loadgen 相同的 Cluster Placement Group
- **等待 10 分钟**再进行后续步骤（实例可能因系统更新重启）

### Step 3: 在各 Loadgen 实例上并行启动 Benchmark
分别 SSH 到每个 Loadgen，启动对应 SUT 的 benchmark：
```bash
ssh -i ~/.ssh/ericyq-global.pem ec2-user@<loadgen_public_ip>
sudo su - root
cd ~/ec2-test-suite && git pull
screen -R ttt -L
USE_CPG=1 bash submit-benchmark-<workload类型>.sh <SUT实例类型>
# Ctrl+A+D 退出 screen 会话（benchmark 在后台继续运行）
```
- workload 类型包括：redis, valkey, mongo, mysql-hammerdb, nginx, milvus 等
- SUT 实例由脚本自动创建，无需手动 launch
- **多个 SUT 并行执行**：各 Loadgen 独立运行，互不影响

### Step 4: 监控 Benchmark 进度
```bash
# 远程检查（对每个 Loadgen 分别执行）
ssh -i ~/.ssh/ericyq-global.pem ec2-user@<loadgen_ip> "sudo tail -20 /root/ec2-test-suite/screenlog.0"
```

### Step 5: 创建监控 Cron Job
启动 benchmark 后，创建固定间隔的 cron job 来监控进度（取代 heartbeat 的不定时轮询）：
```bash
openclaw cron add --name "benchmark-monitor" \
  --every 30m \
  --system-event "Benchmark monitoring: SSH into each Loadgen and check screenlog.0 for progress. Report status to Eric via Slack. If a benchmark has completed, notify Eric. If ALL benchmarks are done, remove this cron with: openclaw cron rm benchmark-monitor" \
  --session main
```
- 固定 30 分钟间隔，确保通知频率稳定
- benchmark 全部完成后，删除该 cron job

### Step 6: 结果自动上传 & 实例自动清理
- 结果目录：~/ec2-test-suite/benchmark-result-files/
- 包含 benchmark 结果文件 + 系统资源监控文件（*dool.txt）
- **脚本完成后会自动将结果文件上传到 S3 存储桶**，无需手动打包或 scp 回 loadgen-seed
- **上传完成后，脚本会自动停止 Loadgen 和 SUT 的 EC2 实例**，无需手动 terminate

### Step 7: 结果分析
- 分析 benchmark 结果文件
- 整理性能指标（吞吐量、延迟等）
- 绘制对比表格和趋势图

## Single 型 Benchmark 操作流程

适用于 specjbb15, ffmpeg, spark, pts 等不需要 Loadgen 的 workload。

### Step 1: 更新代码库（在管理平台上）
```bash
ssh -i ~/.ssh/ericyq-global.pem ec2-user@54.221.55.45
sudo su - root
cd ~/ec2-test-suite && git pull
```

### Step 2: 直接在管理平台启动 Benchmark
无需创建 Loadgen 实例，直接在 loadgen-seed 上执行脚本：
```bash
bash submit-benchmark-singles.sh <workload> <SUT实例类型>
```
- 脚本会自动创建 SUT 实例、执行测试、上传结果到 S3，最后 SUT 自行 terminate
- ⚠️ **必须串行执行！** 同一 workload 的多个实例类型不能并行跑，因为脚本共用 `tf_cfg_${SUT_NAME}` 目录，并行会导致 Terraform 文件互相覆盖

推荐做法 — 写一个串行脚本，用 screen 后台执行：
```bash
cat > /tmp/run-singles-serial.sh << 'SCRIPT'
#!/bin/bash
cd /root/ec2-test-suite

tasks=(
  "specjbb15 r6g.2xlarge"
  "specjbb15 r6i.2xlarge"
  "specjbb15 r7g.2xlarge"
  "ffmpeg r6g.2xlarge"
  "ffmpeg r6i.2xlarge"
  "ffmpeg r7g.2xlarge"
)

for i in "${!tasks[@]}"; do
  task=${tasks[$i]}
  workload=$(echo $task | awk '{print $1}')
  instance=$(echo $task | awk '{print $2}')
  echo ""
  echo "[$(date +%Y%m%d.%H%M%S)] === Task $((i+1))/${#tasks[@]}: ${workload} on ${instance} ==="
  bash submit-benchmark-singles.sh ${workload} ${instance}
  echo "[$(date +%Y%m%d.%H%M%S)] === Task $((i+1))/${#tasks[@]} completed ==="
done

echo ""
echo "[$(date +%Y%m%d.%H%M%S)] === All ${#tasks[@]} tasks completed ==="
SCRIPT

screen -dmS singles-serial -L -Logfile /root/ec2-test-suite/screenlog-singles-serial.log bash /tmp/run-singles-serial.sh
```

### Step 3: 监控进度
Single 型的监控逻辑与 Client-Server 型不同：
- 脚本完成后会**自动 terminate 自身 SUT 实例**（不是 stop，是 terminate）
- **screen 会话还在 → 还有任务在跑**
- **screen 会话消失 → 全部完成**
- 查看日志中的 `Task X/N completed` 来判断当前进度

```bash
# 查看进度
ssh -i ~/.ssh/ericyq-global.pem ec2-user@54.221.55.45 "sudo tail -20 /root/ec2-test-suite/screenlog-singles-serial.log"
# 查看 screen 会话是否还在
ssh -i ~/.ssh/ericyq-global.pem ec2-user@54.221.55.45 "sudo screen -ls"
```

### Step 4: 结果自动上传 & 实例自动清理
- 脚本完成后自动上传结果到 S3
- **SUT 实例会自行 terminate**（脚本在上传完成后执行 self-terminate）

---

## 关键脚本说明
- `launch-instances-single.sh`：创建单个 EC2 实例
- `submit-benchmark-<workload>.sh`：提交 Client-Server 型 benchmark（自动创建 SUT 并执行测试）
- `submit-benchmark-singles.sh`：提交 Single 型 benchmark（自动创建 SUT、执行测试、上传结果、清理实例）
- `USE_CPG=1`：启用 Cluster Placement Group（确保 Loadgen 和 SUT 网络延迟最低，仅用于 Client-Server 型）

## 命名约定
- 结果文件：~/ec2-test-suite/benchmark-result-files/
- 结果自动上传到 S3 存储桶（脚本完成后自动执行）
- Screen 会话名：ttt
- Screen 日志：~/ec2-test-suite/screenlog.0
- 监控文件后缀：*dool.txt

## 任务请求格式

### Client-Server 型
```
请启动 benchmark：
1. Workload类型: redis
2. Loadgen实例类型：c7i.2xlarge
3. SUT实例类型：分别为 r8g.2xlarge, r7i.2xlarge
```

### Single 型
```
请启动 benchmark：
1. Workload类型: specjbb15, ffmpeg
2. Loadgen实例类型：不需要
3. SUT实例类型：分别为 r6g.2xlarge, r6i.2xlarge, r7g.2xlarge
```

## DaVinci 执行流程

### Client-Server 型
1. SSH 管理平台 → git pull
2. 为每个 SUT 创建一个 Loadgen 实例 → 用 cron 定时 10 分钟后启动 benchmark
3. Cron 触发后：分别 SSH 到各 Loadgen → git pull → screen 里并行跑 benchmark
4. 创建监控 cron job（`--every 30m`），固定间隔检查进度并通知 Eric
5. 监控 cron 每次触发时：SSH 检查各 Loadgen 的 screenlog.0，汇报进度
6. 某个 benchmark 完成后 → 通知 Eric（结果已自动上传 S3，实例已自动停止）
7. 全部完成后 → 删除监控 cron job（`openclaw cron rm benchmark-monitor`）

### Single 型
1. SSH 管理平台 → git pull
2. 生成串行执行脚本（所有 workload × SUT 组合按顺序排列），用 screen 后台执行
3. ⚠️ **不能并行** — 同一 workload 共用 Terraform 目录，并行会冲突
4. 创建监控 cron job（`--every 30m`），定期 tail 日志检查进度
5. 某个任务完成后 → 通知 Eric（结果已自动上传 S3，SUT 已 self-terminate）
6. 全部完成后（screen 会话消失）→ 删除监控 cron job