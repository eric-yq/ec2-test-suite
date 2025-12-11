      
#!/usr/bin/env python3
"""
Complete benchmark automation script for PyTorch models in Docker.
This script handles setup, execution, and result collection automatically.
"""

import subprocess
import json
import time
import sys
import re
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any
import argparse


class DockerBenchmarkRunner:
    """Manages Docker-based benchmark execution."""

    def __init__(self, container_name="pytorch-benchmark-test",
                 image="763104351884.dkr.ecr.us-east-1.amazonaws.com/pytorch-inference-arm64:2.6.0-cpu-py312-ubuntu22.04-ec2"):
        self.container_name = container_name
        self.image = image
        self.host_dir = Path.cwd()
        self.container_dir = "/workspace"

    def container_exists(self) -> bool:
        """Check if container exists."""
        result = subprocess.run(
            ["docker", "ps", "-a", "--format", "{{.Names}}"],
            capture_output=True, text=True, check=False
        )
        return self.container_name in result.stdout.split('\n')

    def container_running(self) -> bool:
        """Check if container is running."""
        result = subprocess.run(
            ["docker", "ps", "--format", "{{.Names}}"],
            capture_output=True, text=True, check=False
        )
        return self.container_name in result.stdout.split('\n')

    def setup_container(self, model_name: str, force: bool = False):
        """Set up Docker container with benchmark environment."""
        print("="*80)
        print("Setting up Docker container...")
        print("="*80)
        print(f"Container: {self.container_name}")
        print(f"Image: {self.image}")
        print(f"Model: {model_name}")
        print()

        # Handle existing container
        if self.container_exists():
            if force:
                print(f"Removing existing container '{self.container_name}'...")
                subprocess.run(["docker", "rm", "-f", self.container_name], check=False)
            else:
                print(f"Container '{self.container_name}' already exists.")
                if self.container_running():
                    print("✓ Container is already running")
                    return True
                else:
                    print("Starting existing container...")
                    subprocess.run(["docker", "start", self.container_name], check=True)
                    print("✓ Container started")
                    return True

        # Create new container
        print("Creating Docker container...")
        cmd = [
            "docker", "run", "-d",
            "--name", self.container_name,
            "-v", f"{self.host_dir}:{self.container_dir}",
            "-w", self.container_dir,
            self.image,
            "tail", "-f", "/dev/null"
        ]

        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        if result.returncode != 0:
            print(f"✗ Failed to create container: {result.stderr}")
            return False

        print("✓ Container created and started")
        print()

        # Install dependencies
        print("Installing dependencies...")
        self.docker_exec("pip3 install pyyaml gitpython", check=False)
        print("✓ Dependencies installed")
        print()

        # Clone benchmark repo
        print("Cloning PyTorch benchmark repository...")
        clone_cmd = """
        if [ -d benchmark ]; then
            echo 'Benchmark directory exists, pulling latest...'
            cd benchmark && git pull
        else
            git clone https://github.com/pytorch/benchmark.git
        fi
        """
        self.docker_exec(clone_cmd, shell=True)
        print("✓ Benchmark repository ready")
        print()

        # Install model
        print(f"Installing model: {model_name}...")
        result = self.docker_exec(f"cd benchmark && python3 install.py {model_name}", shell=True)
        if result.returncode == 0:
            print(f"✓ Model '{model_name}' installed successfully")
        else:
            print(f"⚠ Model installation may have failed, check logs")
        print()

        return True

    def docker_exec(self, cmd: str, shell: bool = False, check: bool = False) -> subprocess.CompletedProcess:
        """Execute command in Docker container."""
        if shell:
            docker_cmd = ["docker", "exec", self.container_name, "bash", "-c", cmd]
        else:
            docker_cmd = ["docker", "exec", self.container_name] + cmd.split()

        return subprocess.run(docker_cmd, capture_output=True, text=True, check=check)

    def run_benchmark(self, model: str, test_mode: str, batch_size: int,
                     niter: int, metrics: str, extra_args: List[str]) -> Dict[str, Any]:
        """Run a single benchmark with specified parameters."""
        print(f"\n{'='*80}")
        print(f"Running benchmark: batch_size={batch_size}")
        print(f"{'='*80}")

        # Build command
        cmd_parts = [
            # "export OMP_NUM_THREADS=8 &&",
            # "export OPENBLAS_NUM_THREADS=8 &&",
            # "export BLIS_NUM_THREADS=8 &&",
            # "export MKL_NUM_THREADS=8 &&",
            "cd benchmark &&",
            "python3 run_benchmark.py cpu",
            f"--model {model}",
            f"--test {test_mode}",
            f"--batch-size {batch_size}",
            f"--niter {niter}",
            f"--metrics {metrics}",
        ]

        if extra_args:
            cmd_parts.append(" ".join(extra_args))

        cmd = " ".join(cmd_parts)

        print(f"Command: {cmd}\n")

        start_time = time.time()
        result = self.docker_exec(cmd, shell=True, check=False)
        duration = time.time() - start_time

        success = result.returncode == 0

        # Parse output directory from stdout
        output_dir = None
        if success and result.stdout:
            # Look for output directory in format: /workspace/benchmark/.userbenchmark/cpu/cpu-YYYYMMDDHHMMSS
            for line in result.stdout.split('\n'):
                if '.userbenchmark/cpu/cpu-' in line:
                    # Extract the output directory path
                    match = re.search(r'/workspace/benchmark/(\.userbenchmark/cpu/cpu-\d+)', line)
                    if match:
                        output_dir = match.group(1)
                        break

        # Extract actual metrics from the output file (read from local filesystem via volume mount)
        actual_metrics = {}
        environ_info = {}
        if success and output_dir:
            # Convert container path to host path
            local_metrics_dir = self.host_dir / "benchmark" / output_dir / f"{model}-{test_mode}"

            if local_metrics_dir.exists():
                # Find metrics JSON file dynamically
                metrics_files = list(local_metrics_dir.glob("metrics-*.json"))

                if metrics_files:
                    metrics_file = metrics_files[0]  # Take the first one
                    try:
                        with open(metrics_file, 'r') as f:
                            metrics_data = json.load(f)
                            actual_metrics = metrics_data.get('metrics', {})
                            environ_info = metrics_data.get('environ', {})

                            # Calculate throughput if not present: throughput = batch_size / (latency_ms / 1000)
                            if 'throughput' not in actual_metrics and 'latency' in actual_metrics:
                                latency_seconds = actual_metrics['latency'] / 1000.0
                                actual_metrics['throughput'] = batch_size / latency_seconds if latency_seconds > 0 else 0

                            print(f"✓ Retrieved metrics: latency={actual_metrics.get('latency', 'N/A')}ms, throughput={actual_metrics.get('throughput', 'N/A'):.2f} samples/s")
                    except (json.JSONDecodeError, IOError) as e:
                        print(f"⚠ Failed to read metrics file: {e}")
                else:
                    print(f"⚠ No metrics file found in {local_metrics_dir}")
            else:
                print(f"⚠ Metrics directory not found: {local_metrics_dir}")

        if success:
            print(f"✓ Completed in {duration:.2f}s")
        else:
            print(f"✗ Failed after {duration:.2f}s")
            print(f"Error: {result.stderr[:500]}")

        return {
            "batch_size": batch_size,
            "duration": duration,
            "success": success,
            "output_dir": output_dir,
            "metrics": actual_metrics,
            "environ": environ_info,
            "error": result.stderr[:200] if result.returncode != 0 else None,
        }

    def collect_results(self, model: str, test_mode: str, num_runs: int) -> List[Dict[str, Any]]:
        """Collect benchmark results from container."""
        print(f"\n{'='*80}")
        print("Collecting results...")
        print(f"{'='*80}\n")

        # Find result directories
        find_cmd = f"cd benchmark && find .userbenchmark/cpu -type d -name '{model}-{test_mode}' | tail -{num_runs}"
        result = self.docker_exec(find_cmd, shell=True)

        if result.returncode != 0:
            print("⚠ No result directories found")
            return []

        result_dirs = [d.strip() for d in result.stdout.split('\n') if d.strip()]

        all_metrics = []

        for result_dir in result_dirs:
            # Find metrics files in this directory
            find_metrics_cmd = f"cd benchmark && find {result_dir} -name 'metrics-*.json'"
            metrics_result = self.docker_exec(find_metrics_cmd, shell=True)

            if metrics_result.returncode != 0:
                continue

            metrics_files = [f.strip() for f in metrics_result.stdout.split('\n') if f.strip()]

            for metrics_file in metrics_files:
                # Read metrics file
                cat_cmd = f"cd benchmark && cat {metrics_file}"
                cat_result = self.docker_exec(cat_cmd, shell=True)

                if cat_result.returncode == 0:
                    try:
                        data = json.loads(cat_result.stdout)
                        all_metrics.append({
                            "file": metrics_file,
                            "data": data
                        })
                    except json.JSONDecodeError:
                        continue

        print(f"✓ Collected {len(all_metrics)} result files\n")
        return all_metrics

    def cleanup(self, remove: bool = False):
        """Stop or remove the container."""
        if remove:
            print(f"Removing container '{self.container_name}'...")
            subprocess.run(["docker", "rm", "-f", self.container_name], check=False)
            print("✓ Container removed")
        else:
            print(f"Stopping container '{self.container_name}'...")
            subprocess.run(["docker", "stop", self.container_name], check=False)
            print("✓ Container stopped")


def save_results(results: Dict[str, Any], output_file: Path):
    """Save results to JSON file."""
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)
    print(f"Results saved to: {output_file}")


def print_summary_table(results: Dict[str, Any]):
    """Print formatted results table."""
    print(f"\n{'='*80}")
    print("BENCHMARK RESULTS SUMMARY")
    print(f"{'='*80}")
    print(f"Model: {results['model']}")
    print(f"Test Mode: {results['test_mode']}")
    print(f"Iterations: {results['niter']}")
    print(f"{'='*80}\n")

    metrics_data = results.get('results', [])

    if not metrics_data:
        print("No metrics data available")
        return

    print(f"{'Batch Size':<12} {'Latency (ms)':<15} {'Throughput':<15} {'CPU Peak Mem (MB)':<20}")
    print("-"*80)

    for item in sorted(metrics_data, key=lambda x: x['batch_size']):
        batch_size = item['batch_size']
        metrics = item.get('metrics', {})

        latency = metrics.get('latency', metrics.get('latencies', 'N/A'))
        throughput = metrics.get('throughput', metrics.get('throughputs', 'N/A'))
        cpu_mem = metrics.get('cpu_peak_mem', 'N/A')

        latency_str = f"{latency:.4f}" if isinstance(latency, (int, float)) else str(latency)
        throughput_str = f"{throughput:.4f}" if isinstance(throughput, (int, float)) else str(throughput)
        cpu_mem_str = f"{cpu_mem:.4f}" if isinstance(cpu_mem, (int, float)) else str(cpu_mem)

        print(f"{batch_size:<12} {latency_str:<15} {throughput_str:<15} {cpu_mem_str:<20}")

    print(f"\n{'='*80}\n")


def main():
    parser = argparse.ArgumentParser(description="Run PyTorch benchmarks in Docker")
    parser.add_argument("--model", default="nvidia_deeprecommender", help="Model to benchmark")
    parser.add_argument("--test", default="eval", help="Test mode")
    parser.add_argument("--batch-sizes", default="1,2,4,8,16,32,64,128", help="Comma-separated batch sizes")
    parser.add_argument("--niter", type=int, default=50, help="Number of iterations")
    parser.add_argument("--metrics", default="latencies,throughputs,cpu_peak_mem", help="Metrics to collect")
    parser.add_argument("--extra-args", default="--torchdynamo inductor --freeze_prepack_weights", help="Extra arguments")
    parser.add_argument("--container", default="pytorch-benchmark-test", help="Container name")
    parser.add_argument("--setup-only", action="store_true", help="Only setup, don't run benchmarks")
    parser.add_argument("--arm64", action="store_true", help="Using ARM64 architecture")
    parser.add_argument("--force-setup", action="store_true", help="Force container recreation")
    parser.add_argument("--cleanup", action="store_true", help="Remove container after completion")
    parser.add_argument("-o", "--output", help="Output file for results")

    args = parser.parse_args()

    # Parse batch sizes
    batch_sizes = [int(x.strip()) for x in args.batch_sizes.split(',')]

    # Parse extra args
    extra_args = args.extra_args.split() if args.extra_args else []

    print(f"\n{'#'*80}")
    print("# PyTorch Benchmark Suite")
    print(f"# Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"{'#'*80}\n")

    # Initialize runner
    if args.arm64:
        image="763104351884.dkr.ecr.us-east-1.amazonaws.com/pytorch-inference-arm64:2.6.0-cpu-py312-ubuntu22.04-ec2"
        runner = DockerBenchmarkRunner(container_name=args.container, image=image)
    else:
        image="763104351884.dkr.ecr.us-east-1.amazonaws.com/pytorch-inference:2.6.0-cpu-py312-ubuntu22.04-ec2"
        runner = DockerBenchmarkRunner(container_name=args.container, image=image)

    # Setup container
    if not runner.setup_container(args.model, force=args.force_setup):
        print("✗ Setup failed")
        return 1

    if args.setup_only:
        print("Setup complete. Use --no-setup to run benchmarks with existing container.")
        return 0

    # Run benchmarks
    run_results = []
    for batch_size in batch_sizes:
        result = runner.run_benchmark(
            model=args.model,
            test_mode=args.test,
            batch_size=batch_size,
            niter=args.niter,
            metrics=args.metrics,
            extra_args=extra_args
        )
        run_results.append(result)
        time.sleep(2)  # Pause between runs

    # Extract metrics directly from run_results
    metrics_with_batch = []
    environ_info = {}
    for result in run_results:
        if result['success'] and result.get('metrics'):
            metrics_with_batch.append({
                "batch_size": result['batch_size'],
                "metrics": result['metrics']
            })
            # Capture environ from first successful result
            if not environ_info and result.get('environ'):
                environ_info = result['environ']
        else:
            # Add placeholder for failed runs
            metrics_with_batch.append({
                "batch_size": result['batch_size'],
                "metrics": {},
                "error": result.get('error', 'Unknown error')
            })

    # Prepare final results
    results = {
        "timestamp": datetime.now().isoformat(),
        "model": args.model,
        "test_mode": args.test,
        "niter": args.niter,
        "batch_sizes": batch_sizes,
        "metrics_requested": args.metrics,
        "extra_args": extra_args,
        "environ": environ_info,
        "results": metrics_with_batch,
        "execution_summary": run_results
    }

    # Print summary
    print_summary_table(results)

    # Save results
    if args.output:
        output_file = Path(args.output)
    else:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_file = Path(f"benchmark_results_{timestamp}.json")

    save_results(results, output_file)

    # Cleanup
    if args.cleanup:
        runner.cleanup(remove=True)

    # Print final summary
    successful = sum(1 for r in results['execution_summary'] if r['success'])
    total = len(results['execution_summary'])
    print(f"\nFinal Summary: {successful}/{total} benchmarks completed successfully\n")

    return 0 if successful == total else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\n✗ Interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n✗ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
