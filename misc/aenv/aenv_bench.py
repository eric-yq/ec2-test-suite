#!/usr/bin/env python3
"""
AgentENV Benchmark — x86 vs Graviton
用法: python3 aenv_bench.py <沙箱数量>
示例: python3 aenv_bench.py 100
"""
import subprocess
import sys
import time
import json
import statistics
import platform
import os
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime

# ============ 参数解析 ============
if len(sys.argv) != 2 or not sys.argv[1].isdigit():
    print(f"用法: {sys.argv[0]} <沙箱数量>")
    print(f"示例: {sys.argv[0]} 100")
    sys.exit(1)

NUM_SANDBOXES = int(sys.argv[1])
TEMPLATE = "ubuntu"
MAX_WORKERS = int(subprocess.run("nproc", capture_output=True, text=True).stdout.strip())
RESULTS_FILE = f"aenv_bench_{platform.machine()}_{NUM_SANDBOXES}sandboxes_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"

# ============ 工具函数 ============
def aenv(cmd):
    """执行 aenv 命令，返回 (stdout, returncode, duration_ms)"""
    t0 = time.perf_counter()
    result = subprocess.run(f"aenv {cmd}", shell=True, capture_output=True, text=True)
    dur = (time.perf_counter() - t0) * 1000
    return result.stdout.strip(), result.returncode, dur

def stats(durations):
    s = sorted(durations)
    n = len(s)
    if n == 0:
        return {}
    return {
        "count": n,
        "min_ms": round(s[0], 1),
        "p50_ms": round(s[n // 2], 1),
        "p95_ms": round(s[int(n * 0.95)], 1),
        "p99_ms": round(s[min(int(n * 0.99), n - 1)], 1),
        "max_ms": round(s[-1], 1),
        "mean_ms": round(statistics.mean(s), 1),
        "total_wall_ms": None,
    }

# ============ 元信息 ============
results = {
    "arch": platform.machine(),
    "vcpus": os.cpu_count(),
    "nproc": MAX_WORKERS,
    "num_sandboxes": NUM_SANDBOXES,
    "max_workers": MAX_WORKERS,
    "timestamp": datetime.now().isoformat(),
    "kernel": os.popen("uname -r").read().strip(),
    "phases": {}
}

print(f"{'=' * 60}")
print(f"AgentENV Benchmark — {platform.machine()} / nproc={MAX_WORKERS}")
print(f"Sandboxes: {NUM_SANDBOXES} | Concurrency: {MAX_WORKERS}")
print(f"{'=' * 60}")

# ========== Phase 1: 批量启动 ==========
print(f"\n[Phase 1] 批量启动 {NUM_SANDBOXES} 个沙箱...")
sandbox_ids = []
start_durs = []

t0 = time.perf_counter()
with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
    futures = [pool.submit(aenv, f"start {TEMPLATE} --detach") for _ in range(NUM_SANDBOXES)]
    for f in as_completed(futures):
        stdout, rc, dur = f.result()
        if rc == 0 and stdout:
            sandbox_ids.append(stdout.split("\n")[-1].strip())
            start_durs.append(dur)
wall = (time.perf_counter() - t0) * 1000

s = stats(start_durs)
s["total_wall_ms"] = round(wall, 1)
results["phases"]["start"] = s
print(f"    ✓ {len(sandbox_ids)}/{NUM_SANDBOXES} 成功")
print(f"    Wall: {wall:.0f}ms | Mean: {s['mean_ms']:.0f}ms | P50: {s['p50_ms']:.0f}ms | P95: {s['p95_ms']:.0f}ms | P99: {s['p99_ms']:.0f}ms")

time.sleep(2)

# ========== Phase 2: 批量执行（轻量 echo） ==========
print(f"\n[Phase 2] 批量 exec echo...")
exec_durs = []

t0 = time.perf_counter()
with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
    futures = [pool.submit(aenv, f"exec {sid} -- echo ok") for sid in sandbox_ids]
    for f in as_completed(futures):
        _, rc, dur = f.result()
        exec_durs.append(dur)
wall = (time.perf_counter() - t0) * 1000

s = stats(exec_durs)
s["total_wall_ms"] = round(wall, 1)
results["phases"]["exec_echo"] = s
print(f"    Wall: {wall:.0f}ms | Mean: {s['mean_ms']:.0f}ms | P50: {s['p50_ms']:.0f}ms | P95: {s['p95_ms']:.0f}ms")

# ========== Phase 3: 批量执行（计算密集 — sha256sum 10MB） ==========
print(f"\n[Phase 3] 批量 exec 计算密集 (sha256sum 10MB)...")
heavy_durs = []

t0 = time.perf_counter()
with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
    cmd = "dd if=/dev/urandom bs=1M count=10 2>/dev/null | sha256sum"
    futures = [pool.submit(aenv, f"exec {sid} -- bash -c \"{cmd}\"") for sid in sandbox_ids]
    for f in as_completed(futures):
        _, rc, dur = f.result()
        heavy_durs.append(dur)
wall = (time.perf_counter() - t0) * 1000

s = stats(heavy_durs)
s["total_wall_ms"] = round(wall, 1)
results["phases"]["exec_heavy"] = s
print(f"    Wall: {wall:.0f}ms | Mean: {s['mean_ms']:.0f}ms | P50: {s['p50_ms']:.0f}ms | P95: {s['p95_ms']:.0f}ms")

# ========== Phase 4: 批量暂停 ==========
print(f"\n[Phase 4] 批量暂停...")
pause_durs = []

t0 = time.perf_counter()
with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
    futures = [pool.submit(aenv, f"pause {sid}") for sid in sandbox_ids]
    for f in as_completed(futures):
        _, _, dur = f.result()
        pause_durs.append(dur)
wall = (time.perf_counter() - t0) * 1000

s = stats(pause_durs)
s["total_wall_ms"] = round(wall, 1)
results["phases"]["pause"] = s
print(f"    Wall: {wall:.0f}ms | Mean: {s['mean_ms']:.0f}ms | P50: {s['p50_ms']:.0f}ms | P95: {s['p95_ms']:.0f}ms")

# ========== Phase 5: 批量恢复 ==========
print(f"\n[Phase 5] 批量恢复...")
resume_durs = []

t0 = time.perf_counter()
with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
    futures = [pool.submit(aenv, f"resume {sid}") for sid in sandbox_ids]
    for f in as_completed(futures):
        _, _, dur = f.result()
        resume_durs.append(dur)
wall = (time.perf_counter() - t0) * 1000

s = stats(resume_durs)
s["total_wall_ms"] = round(wall, 1)
results["phases"]["resume"] = s
print(f"    Wall: {wall:.0f}ms | Mean: {s['mean_ms']:.0f}ms | P50: {s['p50_ms']:.0f}ms | P95: {s['p95_ms']:.0f}ms")

# ========== Phase 6: 恢复后执行（验证状态） ==========
print(f"\n[Phase 6] 恢复后 exec echo（验证状态完整性）...")
exec2_durs = []

t0 = time.perf_counter()
with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
    futures = [pool.submit(aenv, f"exec {sid} -- echo alive") for sid in sandbox_ids]
    for f in as_completed(futures):
        _, rc, dur = f.result()
        exec2_durs.append(dur)
wall = (time.perf_counter() - t0) * 1000

s = stats(exec2_durs)
s["total_wall_ms"] = round(wall, 1)
results["phases"]["exec_after_resume"] = s
print(f"    Wall: {wall:.0f}ms | Mean: {s['mean_ms']:.0f}ms | P50: {s['p50_ms']:.0f}ms | P95: {s['p95_ms']:.0f}ms")

# ========== Phase 7: 内存快照 ==========
print(f"\n[Phase 7] Host 资源状态...")
mem = os.popen("free -m").read().strip()
print(f"    {mem}")
results["host_memory"] = mem

# ========== Phase 8: 批量删除 ==========
print(f"\n[Phase 8] 批量删除...")
del_durs = []

t0 = time.perf_counter()
with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
    futures = [pool.submit(aenv, f"delete {sid}") for sid in sandbox_ids]
    for f in as_completed(futures):
        _, _, dur = f.result()
        del_durs.append(dur)
wall = (time.perf_counter() - t0) * 1000

s = stats(del_durs)
s["total_wall_ms"] = round(wall, 1)
results["phases"]["delete"] = s
print(f"    Wall: {wall:.0f}ms | Mean: {s['mean_ms']:.0f}ms | P50: {s['p50_ms']:.0f}ms")

# ========== 保存结果 ==========
with open(RESULTS_FILE, "w") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)

print(f"\n{'=' * 60}")
print(f"✓ 完成! 结果: {RESULTS_FILE}")
print(f"{'=' * 60}")
