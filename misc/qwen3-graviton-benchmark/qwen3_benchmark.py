#!/usr/bin/env python3
"""
Qwen3-0.6B-BF16 Benchmark Script for EC2 Instances
Supports c7i.2xlarge (Intel) and c8g.2xlarge (Graviton) instances
"""

import torch
import time
import psutil
import platform
import json
import argparse
from datetime import datetime
from transformers import AutoTokenizer, AutoModelForCausalLM
import numpy as np
import gc
import os

class Qwen3Benchmark:
    def __init__(self, model_name="Qwen/Qwen2.5-0.5B", device="auto"):
        self.model_name = model_name
        self.device = self._get_device(device)
        self.model = None
        self.tokenizer = None
        self.results = {}
        
    def _get_device(self, device):
        """确定使用的设备"""
        if device == "auto":
            if torch.cuda.is_available():
                return "cuda"
            elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
                return "mps"
            else:
                return "cpu"
        return device
    
    def _get_system_info(self):
        """获取系统信息"""
        return {
            "platform": platform.platform(),
            "processor": platform.processor(),
            "architecture": platform.architecture(),
            "cpu_count": psutil.cpu_count(logical=False),
            "cpu_count_logical": psutil.cpu_count(logical=True),
            "memory_total_gb": round(psutil.virtual_memory().total / (1024**3), 2),
            "python_version": platform.python_version(),
            "pytorch_version": torch.__version__,
            "device": self.device,
            "instance_type": os.environ.get("EC2_INSTANCE_TYPE", "unknown")
        }
    
    def load_model(self):
        """加载模型和tokenizer"""
        print(f"Loading model {self.model_name} on {self.device}...")
        start_time = time.time()
        
        try:
            # 加载tokenizer
            self.tokenizer = AutoTokenizer.from_pretrained(
                self.model_name,
                trust_remote_code=True
            )
            
            # 加载模型，使用BF16精度
            self.model = AutoModelForCausalLM.from_pretrained(
                self.model_name,
                torch_dtype=torch.bfloat16,
                device_map=self.device if self.device != "cpu" else None,
                trust_remote_code=True,
                low_cpu_mem_usage=True
            )
            
            if self.device == "cpu":
                self.model = self.model.to(self.device)
            
            # 设置为评估模式
            self.model.eval()
            
            load_time = time.time() - start_time
            print(f"Model loaded in {load_time:.2f} seconds")
            
            return load_time
            
        except Exception as e:
            print(f"Error loading model: {e}")
            raise
    
    def benchmark_inference(self, prompt_lengths=[50, 100, 200, 500], 
                          max_new_tokens=100, num_runs=5):
        """推理性能测试"""
        print("\n=== Inference Benchmark ===")
        inference_results = {}
        
        # 准备不同长度的测试prompt
        base_prompt = "The future of artificial intelligence is "
        test_prompts = {}
        
        for length in prompt_lengths:
            # 创建指定长度的prompt
            words = base_prompt.split()
            while len(" ".join(words).split()) < length:
                words.extend(base_prompt.split())
            prompt = " ".join(words[:length])
            test_prompts[length] = prompt
        
        for prompt_length in prompt_lengths:
            print(f"\nTesting prompt length: {prompt_length} tokens")
            prompt = test_prompts[prompt_length]
            
            times = []
            tokens_per_second = []
            
            for run in range(num_runs):
                print(f"  Run {run + 1}/{num_runs}")
                
                # 清理GPU内存
                if self.device != "cpu":
                    torch.cuda.empty_cache()
                gc.collect()
                
                # 编码输入
                inputs = self.tokenizer(prompt, return_tensors="pt")
                if self.device != "cpu":
                    inputs = {k: v.to(self.device) for k, v in inputs.items()}
                
                # 推理计时
                start_time = time.time()
                
                with torch.no_grad():
                    outputs = self.model.generate(
                        **inputs,
                        max_new_tokens=max_new_tokens,
                        do_sample=False,
                        pad_token_id=self.tokenizer.eos_token_id,
                        temperature=1.0,
                        use_cache=True
                    )
                
                end_time = time.time()
                inference_time = end_time - start_time
                
                # 计算tokens/second
                generated_tokens = outputs.shape[1] - inputs['input_ids'].shape[1]
                tps = generated_tokens / inference_time
                
                times.append(inference_time)
                tokens_per_second.append(tps)
                
                print(f"    Time: {inference_time:.3f}s, Tokens/s: {tps:.2f}")
            
            # 统计结果
            inference_results[prompt_length] = {
                "avg_time": np.mean(times),
                "std_time": np.std(times),
                "min_time": np.min(times),
                "max_time": np.max(times),
                "avg_tokens_per_second": np.mean(tokens_per_second),
                "std_tokens_per_second": np.std(tokens_per_second),
                "max_new_tokens": max_new_tokens,
                "runs": num_runs
            }
        
        return inference_results
    
    def benchmark_memory_usage(self):
        """内存使用测试"""
        print("\n=== Memory Usage Benchmark ===")
        
        # 系统内存
        memory_info = psutil.virtual_memory()
        
        # GPU内存 (如果可用)
        gpu_memory = {}
        if self.device == "cuda" and torch.cuda.is_available():
            gpu_memory = {
                "allocated": torch.cuda.memory_allocated() / (1024**3),
                "cached": torch.cuda.memory_reserved() / (1024**3),
                "max_allocated": torch.cuda.max_memory_allocated() / (1024**3)
            }
        
        memory_results = {
            "system_memory_used_gb": (memory_info.total - memory_info.available) / (1024**3),
            "system_memory_total_gb": memory_info.total / (1024**3),
            "system_memory_percent": memory_info.percent,
            "gpu_memory": gpu_memory
        }
        
        print(f"System Memory: {memory_results['system_memory_used_gb']:.2f}GB / {memory_results['system_memory_total_gb']:.2f}GB ({memory_results['system_memory_percent']:.1f}%)")
        if gpu_memory:
            print(f"GPU Memory: Allocated {gpu_memory['allocated']:.2f}GB, Cached {gpu_memory['cached']:.2f}GB")
        
        return memory_results
    
    def benchmark_throughput(self, batch_sizes=[1, 2, 4], sequence_length=100, num_batches=10):
        """吞吐量测试"""
        print("\n=== Throughput Benchmark ===")
        throughput_results = {}
        
        base_prompt = "Artificial intelligence is transforming the world by "
        
        for batch_size in batch_sizes:
            print(f"\nTesting batch size: {batch_size}")
            
            # 准备批量输入
            prompts = [base_prompt] * batch_size
            
            total_tokens = 0
            total_time = 0
            
            for batch_idx in range(num_batches):
                print(f"  Batch {batch_idx + 1}/{num_batches}")
                
                # 清理内存
                if self.device != "cpu":
                    torch.cuda.empty_cache()
                gc.collect()
                
                # 编码输入
                inputs = self.tokenizer(prompts, return_tensors="pt", padding=True, truncation=True)
                if self.device != "cpu":
                    inputs = {k: v.to(self.device) for k, v in inputs.items()}
                
                # 推理计时
                start_time = time.time()
                
                with torch.no_grad():
                    outputs = self.model.generate(
                        **inputs,
                        max_new_tokens=50,
                        do_sample=False,
                        pad_token_id=self.tokenizer.eos_token_id,
                        use_cache=True
                    )
                
                end_time = time.time()
                batch_time = end_time - start_time
                
                # 计算生成的token数量
                batch_tokens = (outputs.shape[1] - inputs['input_ids'].shape[1]) * batch_size
                
                total_tokens += batch_tokens
                total_time += batch_time
                
                print(f"    Batch time: {batch_time:.3f}s, Tokens: {batch_tokens}")
            
            # 计算平均吞吐量
            avg_throughput = total_tokens / total_time
            
            throughput_results[batch_size] = {
                "total_tokens": total_tokens,
                "total_time": total_time,
                "avg_throughput_tokens_per_second": avg_throughput,
                "num_batches": num_batches
            }
            
            print(f"  Average throughput: {avg_throughput:.2f} tokens/second")
        
        return throughput_results
    
    def run_full_benchmark(self):
        """运行完整的benchmark测试"""
        print("Starting Qwen3-0.6B-BF16 Benchmark")
        print("=" * 50)
        
        # 获取系统信息
        system_info = self._get_system_info()
        print("System Information:")
        for key, value in system_info.items():
            print(f"  {key}: {value}")
        
        # 加载模型
        load_time = self.load_model()
        
        # 运行各项测试
        inference_results = self.benchmark_inference()
        memory_results = self.benchmark_memory_usage()
        throughput_results = self.benchmark_throughput()
        
        # 汇总结果
        self.results = {
            "timestamp": datetime.now().isoformat(),
            "system_info": system_info,
            "model_name": self.model_name,
            "device": self.device,
            "model_load_time": load_time,
            "inference_benchmark": inference_results,
            "memory_usage": memory_results,
            "throughput_benchmark": throughput_results
        }
        
        return self.results
    
    def save_results(self, filename=None):
        """保存测试结果到JSON文件"""
        if filename is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            instance_type = self.results.get("system_info", {}).get("instance_type", "unknown")
            filename = f"qwen3_benchmark_{instance_type}_{timestamp}.json"
        
        with open(filename, 'w') as f:
            json.dump(self.results, f, indent=2)
        
        print(f"\nResults saved to: {filename}")
        return filename

def main():
    parser = argparse.ArgumentParser(description="Qwen3-0.6B-BF16 Benchmark")
    parser.add_argument("--model", default="Qwen/Qwen2.5-0.5B", 
                       help="Model name or path")
    parser.add_argument("--device", default="auto", 
                       help="Device to use (auto, cpu, cuda, mps)")
    parser.add_argument("--output", help="Output filename for results")
    
    args = parser.parse_args()
    
    # 创建benchmark实例
    benchmark = Qwen3Benchmark(model_name=args.model, device=args.device)
    
    try:
        # 运行benchmark
        results = benchmark.run_full_benchmark()
        
        # 保存结果
        output_file = benchmark.save_results(args.output)
        
        # 打印摘要
        print("\n" + "=" * 50)
        print("BENCHMARK SUMMARY")
        print("=" * 50)
        
        print(f"Model: {results['model_name']}")
        print(f"Device: {results['device']}")
        print(f"Load Time: {results['model_load_time']:.2f}s")
        
        print("\nInference Performance:")
        for prompt_len, stats in results['inference_benchmark'].items():
            print(f"  {prompt_len} tokens: {stats['avg_tokens_per_second']:.2f} ± {stats['std_tokens_per_second']:.2f} tokens/s")
        
        print(f"\nMemory Usage: {results['memory_usage']['system_memory_used_gb']:.2f}GB")
        
        print("\nThroughput:")
        for batch_size, stats in results['throughput_benchmark'].items():
            print(f"  Batch {batch_size}: {stats['avg_throughput_tokens_per_second']:.2f} tokens/s")
        
    except Exception as e:
        print(f"Benchmark failed: {e}")
        raise

if __name__ == "__main__":
    main()
