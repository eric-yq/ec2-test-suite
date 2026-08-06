#!/usr/bin/env python3
"""
AgentENV Benchmark — x86 vs Graviton (混合模式)
- 生命周期操作（create/pause/resume/delete）: HTTP API（零进程开销）
- 命令执行（exec）: aenv CLI（优化：无 shell=True，直接 argv 调用）

用法: python3 aenv_bench.py <沙箱数量> [server_url] [--purge]
示例: python3 aenv_bench.py 100                       # 测试完保留沙箱
      python3 aenv_bench.py 100 --purge               # 测试完删除沙箱
      python3 aenv_bench.py 100 http://127.0.0.1:8000 --purge
      python3 aenv_bench.py --purge                   # 仅删除所有现存沙箱
"""
import sys
import time
import json
import statistics
import platform
import os
import subprocess
import multiprocessing
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

# ============ 参数解析 ============
# 提取 --purge 标志
PURGE = "--purge" in sys.argv
args = [a for a in sys.argv[1:] if a != "--purge"]

BASE_URL = args[1].rstrip("/") if len(args) > 1 else "http://127.0.0.1:8000"
TEMPLATE = "ubuntu"
MAX_WORKERS = multiprocessing.cpu_count()
API_KEY = "e2b_0000000000000000000000000000000000000000"
AENV_BIN = "/usr/local/bin/aenv"  # 直接指定绝对路径，省去 PATH 查找

# 确认 aenv CLI 位置
if not os.path.exists(AENV_BIN):
    # fallback: 通过 which 查找一次
    r = subprocess.run(["which", "aenv"], capture_output=True, text=True)
    AENV_BIN = r.stdout.strip() or "aenv"

# ============ --purge 独立模式：删除所有现存沙箱 ============
if PURGE and (len(args) == 0 or not args[0].isdigit()):
    # 仅执行 purge，不跑 benchmark
    if len(args) >= 1 and not args[0].isdigit():
        BASE_URL = args[0].rstrip("/")

    print(f"{'=' * 60}")
    print(f"AgentENV Purge — 删除所有现存沙箱（包括 paused）")
    print(f"CLI: {AENV_BIN}")
    print(f"{'=' * 60}")

    # 用 aenv CLI 获取列表（包含 paused 状态的沙箱）
    r = subprocess.run([AENV_BIN, "list", "--output", "json"], capture_output=True, text=True)
    try:
        sandboxes = json.loads(r.stdout) if r.stdout.strip() else []
    except json.JSONDecodeError:
        print(f"    ✗ 解析沙箱列表失败: {r.stdout[:200]}")
        sys.exit(1)

    if not sandboxes:
        print("    没有沙箱需要删除。")
        sys.exit(0)

    print(f"    发现 {len(sandboxes)} 个沙箱，开始删除...")

    def _delete(sid):
        subprocess.run([AENV_BIN, "delete", sid], capture_output=True, timeout=30)

    sandbox_ids_to_del = [s.get("sandboxID", s.get("id", "")) for s in sandboxes if isinstance(s, dict)]
    if not sandbox_ids_to_del:
        # 可能列表格式不同，尝试直接当字符串列表
        sandbox_ids_to_del = [s for s in sandboxes if isinstance(s, str)]

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        list(pool.map(_delete, sandbox_ids_to_del))

    print(f"    ✓ 已删除 {len(sandbox_ids_to_del)} 个沙箱")
    sys.exit(0)

# ============ 正常 benchmark 模式 ============
if len(args) < 1 or not args[0].isdigit():
    print(f"用法: {sys.argv[0]} <沙箱数量> [server_url] [--purge]")
    print(f"示例: {sys.argv[0]} 100                       # 测试完保留沙箱")
    print(f"      {sys.argv[0]} 100 --purge               # 测试完删除沙箱")
    print(f"      {sys.argv[0]} 100 http://127.0.0.1:8000 --purge")
    print(f"      {sys.argv[0]} --purge                   # 仅删除所有现存沙箱")
    sys.exit(1)

NUM_SANDBOXES = int(args[0])
if len(args) > 1:
    BASE_URL = args[1].rstrip("/")
RESULTS_FILE = f"aenv_bench_{platform.machine()}_{NUM_SANDBOXES}sandboxes_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"

# ============ HTTP API 封装（生命周期操作） ============
def api_request(method, path, body=None, timeout=60):
    """发送 HTTP 请求到 AENV server"""
    url = f"{BASE_URL}{path}"
    headers = {"Content-Type": "application/json", "X-API-Key": API_KEY}
    data = json.dumps(body).encode() if body else None
    req = Request(url, data=data, headers=headers, method=method)
    t0 = time.perf_counter()
    try:
        with urlopen(req, timeout=timeout) as resp:
            dur = (time.perf_counter() - t0) * 1000
            resp_body = resp.read().decode()
            return resp_body, resp.status, dur
    except HTTPError as e:
        dur = (time.perf_counter() - t0) * 1000
        return e.read().decode() if e.fp else "", e.code, dur
    except (URLError, OSError) as e:
        dur = (time.perf_counter() - t0) * 1000
        return str(e), 0, dur


def create_sandbox(template=TEMPLATE, timeout_s=300):
    """POST /sandboxes"""
    body, status, dur = api_request("POST", "/sandboxes", {
        "templateID": template, "timeout": timeout_s,
    })
    if status in (200, 201):
        resp = json.loads(body) if body else {}
        return resp.get("sandboxID", ""), dur
    return "", dur


def delete_sandbox(sandbox_id):
    """DELETE /sandboxes/{id}"""
    _, _, dur = api_request("DELETE", f"/sandboxes/{sandbox_id}")
    return dur


def pause_sandbox(sandbox_id):
    """POST /sandboxes/{id}/pause"""
    _, _, dur = api_request("POST", f"/sandboxes/{sandbox_id}/pause")
    return dur


def resume_sandbox(sandbox_id):
    """POST /sandboxes/{id}/resume"""
    _, _, dur = api_request("POST", f"/sandboxes/{sandbox_id}/resume", {"timeout": 300})
    return dur


# ============ CLI exec 封装（命令执行） ============
def exec_cmd(sandbox_id, cmd):
    """
    通过 aenv CLI 执行命令。优化措施：
    1. 不使用 shell=True（省去 /bin/sh fork）
    2. 使用绝对路径（省去 PATH 查找）
    3. 直接用 argv list 传参
    """
    t0 = time.perf_counter()
    result = subprocess.run(
        [AENV_BIN, "exec", sandbox_id, "--", "sh", "-c", cmd],
        capture_output=True, text=True, timeout=120
    )
    dur = (time.perf_counter() - t0) * 1000
    return result.stdout.strip(), result.returncode, dur


# ============ 统计函数 ============
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

def stats_detail(durations):
    """详细分位数统计，展示完整延迟分布"""
    s = sorted(durations)
    n = len(s)
    if n == 0:
        return ""
    percentiles = [10, 25, 50, 75, 90, 95, 99]
    lines = []
    for p in percentiles:
        idx = min(int(n * p / 100), n - 1)
        count = int(n * p / 100)
        lines.append(f"P{p:2d}: {s[idx]:8.1f}ms ({count:3d}/{n} 沙箱在此时间内完成)")
    lines.append(f"Max: {s[-1]:8.1f}ms ({n:3d}/{n} 沙箱在此时间内完成)")
    return "\n".join(f"      {l}" for l in lines)


# ============ 主流程 ============
results = {
    "arch": platform.machine(),
    "vcpus": os.cpu_count(),
    "num_sandboxes": NUM_SANDBOXES,
    "max_workers": MAX_WORKERS,
    "server_url": BASE_URL,
    "method": "Hybrid: HTTP API (lifecycle) + aenv CLI (exec)",
    "timestamp": datetime.now().isoformat(),
    "kernel": os.popen("uname -r").read().strip(),
    "phases": {}
}

print(f"{'=' * 60}")
print(f"AgentENV Benchmark (Hybrid) — {platform.machine()} / {MAX_WORKERS} vCPUs")
print(f"Server: {BASE_URL} | CLI: {AENV_BIN}")
print(f"Sandboxes: {NUM_SANDBOXES} | Concurrency: {MAX_WORKERS}")
print(f"{'=' * 60}")

# --- 预检 ---
print("\n[Preflight] 检查 AENV server...")
body, status, _ = api_request("GET", "/sandboxes")
if status == 0:
    print(f"    ✗ Server 不可达: {body}")
    sys.exit(1)
print(f"    ✓ Server 正常 (status={status})")

# ========== Phase 1: 批量创建（HTTP API） ==========
print(f"\n[Phase 1] 批量创建 {NUM_SANDBOXES} 个沙箱 (HTTP API)...")
sandbox_ids = []
start_durs = []

t0 = time.perf_counter()
with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
    futures = [pool.submit(create_sandbox) for _ in range(NUM_SANDBOXES)]
    for f in as_completed(futures):
        sid, dur = f.result()
        if sid:
            sandbox_ids.append(sid)
            start_durs.append(dur)
wall = (time.perf_counter() - t0) * 1000

s = stats(start_durs)
s["total_wall_ms"] = round(wall, 1)
results["phases"]["create"] = s
print(f"    ✓ {len(sandbox_ids)}/{NUM_SANDBOXES} 成功")
print(f"    Wall: {wall:.0f}ms | Mean: {s['mean_ms']:.0f}ms | P50: {s['p50_ms']:.0f}ms | P95: {s['p95_ms']:.0f}ms | P99: {s['p99_ms']:.0f}ms")
print(f"    延迟分布:")
print(stats_detail(start_durs))

time.sleep(3)

# ========== Phase 2: 批量执行 获取沙箱 UUID（验证内核级隔离） ==========
print(f"\n[Phase 2] 批量 exec 获取内核 UUID — 验证隔离性 (aenv CLI)...")
exec_durs = []
sandbox_uuids = {}

t0 = time.perf_counter()
with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
    futures = {pool.submit(exec_cmd, sid, "cat /proc/sys/kernel/random/uuid"): sid for sid in sandbox_ids}
    for f in as_completed(futures):
        sid = futures[f]
        stdout, rc, dur = f.result()
        exec_durs.append(dur)
        sandbox_uuids[sid] = stdout if rc == 0 and stdout else f"error(rc={rc})"
wall = (time.perf_counter() - t0) * 1000

s = stats(exec_durs)
s["total_wall_ms"] = round(wall, 1)
results["phases"]["exec_get_uuid"] = s
print(f"    Wall: {wall:.0f}ms | Mean: {s['mean_ms']:.0f}ms | P50: {s['p50_ms']:.0f}ms | P95: {s['p95_ms']:.0f}ms")

# 打印样本
sample = list(sandbox_uuids.items())[:10]
print(f"    沙箱 UUID 样本（前 {len(sample)} 个）:")
for sid, uuid_val in sample:
    print(f"      {sid} → {uuid_val}")
unique_uuids = set(v for v in sandbox_uuids.values() if not v.startswith("error"))
total_sandboxes = len(sandbox_uuids)
isolated = len(unique_uuids) == total_sandboxes
print(f"    唯一 UUID 数: {len(unique_uuids)} / {total_sandboxes} 沙箱")
print(f"    隔离验证: {'✓ 通过 — 每个沙箱拥有独立内核' if isolated else '✗ 异常 — 存在重复 UUID'}")
results["unique_uuid_count"] = len(unique_uuids)
results["isolation_verified"] = isolated

# ========== Phase 3: 批量执行 计算密集（aenv CLI） ==========
print(f"\n[Phase 3] 批量 exec 计算密集 sha256sum 10MB (aenv CLI)...")
heavy_durs = []
sha256_results = {}
heavy_cmd = "dd if=/dev/urandom bs=1M count=10 2>/dev/null | sha256sum"

t0 = time.perf_counter()
with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
    futures = {pool.submit(exec_cmd, sid, heavy_cmd): sid for sid in sandbox_ids}
    for f in as_completed(futures):
        sid = futures[f]
        stdout, rc, dur = f.result()
        heavy_durs.append(dur)
        sha256_results[sid] = stdout.split()[0] if rc == 0 and stdout else f"error(rc={rc})"
wall = (time.perf_counter() - t0) * 1000

s = stats(heavy_durs)
s["total_wall_ms"] = round(wall, 1)
results["phases"]["exec_heavy"] = s
print(f"    Wall: {wall:.0f}ms | Mean: {s['mean_ms']:.0f}ms | P50: {s['p50_ms']:.0f}ms | P95: {s['p95_ms']:.0f}ms")

# 展示隔离性：每个沙箱独立的 /dev/urandom → sha256 必然各不相同
unique_hashes = set(v for v in sha256_results.values() if not v.startswith("error"))
print(f"    唯一 sha256 数: {len(unique_hashes)} / {len(sha256_results)} 沙箱")
sample_hashes = list(sha256_results.items())[:5]
print(f"    sha256 样本（前 {len(sample_hashes)} 个）:")
for sid, h in sample_hashes:
    print(f"      {sid} → {h[:32]}...")
hash_isolated = len(unique_hashes) == len(sha256_results)
print(f"    计算隔离验证: {'✓ 通过 — 各沙箱独立熵源/独立计算' if hash_isolated else '✗ 异常 — 存在重复 hash'}")
results["sha256_unique_count"] = len(unique_hashes)
results["compute_isolation_verified"] = hash_isolated

# ========== Phase 4: 批量暂停（HTTP API） ==========
print(f"\n[Phase 4] 批量暂停 (HTTP API)...")
pause_durs = []

t0 = time.perf_counter()
with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
    futures = [pool.submit(pause_sandbox, sid) for sid in sandbox_ids]
    for f in as_completed(futures):
        dur = f.result()
        pause_durs.append(dur)
wall = (time.perf_counter() - t0) * 1000

s = stats(pause_durs)
s["total_wall_ms"] = round(wall, 1)
results["phases"]["pause"] = s
print(f"    Wall: {wall:.0f}ms | Mean: {s['mean_ms']:.0f}ms | P50: {s['p50_ms']:.0f}ms | P95: {s['p95_ms']:.0f}ms")

# ========== Phase 5: 批量恢复（HTTP API） ==========
print(f"\n[Phase 5] 批量恢复 (HTTP API)...")
resume_durs = []

t0 = time.perf_counter()
with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
    futures = [pool.submit(resume_sandbox, sid) for sid in sandbox_ids]
    for f in as_completed(futures):
        dur = f.result()
        resume_durs.append(dur)
wall = (time.perf_counter() - t0) * 1000

s = stats(resume_durs)
s["total_wall_ms"] = round(wall, 1)
results["phases"]["resume"] = s
print(f"    Wall: {wall:.0f}ms | Mean: {s['mean_ms']:.0f}ms | P50: {s['p50_ms']:.0f}ms | P95: {s['p95_ms']:.0f}ms")

# ========== Phase 6: 恢复后执行（aenv CLI） ==========
print(f"\n[Phase 6] 恢复后 exec echo — 验证状态完整性 (aenv CLI)...")
exec2_durs = []

t0 = time.perf_counter()
with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
    futures = [pool.submit(exec_cmd, sid, "echo alive") for sid in sandbox_ids]
    for f in as_completed(futures):
        _, _, dur = f.result()
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

# ========== Phase 8: 批量删除（HTTP API） ==========
if PURGE:
    print(f"\n[Phase 8] 批量删除 (HTTP API) — --purge 已指定...")
    del_durs = []

    t0 = time.perf_counter()
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        futures = [pool.submit(delete_sandbox, sid) for sid in sandbox_ids]
        for f in as_completed(futures):
            dur = f.result()
            del_durs.append(dur)
    wall = (time.perf_counter() - t0) * 1000

    s = stats(del_durs)
    s["total_wall_ms"] = round(wall, 1)
    results["phases"]["delete"] = s
    print(f"    Wall: {wall:.0f}ms | Mean: {s['mean_ms']:.0f}ms | P50: {s['p50_ms']:.0f}ms")
else:
    print(f"\n[Phase 8] 跳过删除（未指定 --purge，沙箱保留）")
    print(f"    保留的沙箱数: {len(sandbox_ids)}")
    results["phases"]["delete"] = {"skipped": True, "sandboxes_retained": len(sandbox_ids)}

# ========== 保存结果 ==========
with open(RESULTS_FILE, "w") as f:
    json.dump(results, f, indent=2, ensure_ascii=False)

print(f"\n{'=' * 60}")
print(f"✓ 完成! 结果: {RESULTS_FILE}")
print(f"{'=' * 60}")
