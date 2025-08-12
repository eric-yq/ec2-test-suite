#!/usr/bin/env python3
"""
Qwen3 Benchmark Results Analyzer
比较 c7i.2xlarge 和 c8g.2xlarge 的性能结果
"""

import json
import argparse
import glob
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path

class BenchmarkAnalyzer:
    def __init__(self):
        self.results = {}
    
    def load_results(self, pattern="qwen3_benchmark_*.json"):
        """加载所有benchmark结果文件"""
        files = glob.glob(pattern)
        
        for file in files:
            with open(file, 'r') as f:
                data = json.load(f)
                instance_type = data.get('system_info', {}).get('instance_type', 'unknown')
                self.results[instance_type] = data
                print(f"Loaded results for {instance_type} from {file}")
        
        return len(files)
    
    def compare_inference_performance(self):
        """比较推理性能"""
        print("\n=== Inference Performance Comparison ===")
        
        comparison_data = []
        
        for instance_type, data in self.results.items():
            inference_data = data.get('inference_benchmark', {})
            
            for prompt_length, stats in inference_data.items():
                comparison_data.append({
                    'instance_type': instance_type,
                    'prompt_length': prompt_length,
                    'avg_tokens_per_second': stats['avg_tokens_per_second'],
                    'std_tokens_per_second': stats['std_tokens_per_second'],
                    'avg_time': stats['avg_time']
                })
        
        if not comparison_data:
            print("No inference data found")
            return
        
        df = pd.DataFrame(comparison_data)
        
        # 按prompt长度分组比较
        for prompt_len in df['prompt_length'].unique():
            print(f"\nPrompt Length: {prompt_len} tokens")
            subset = df[df['prompt_length'] == prompt_len]
            
            for _, row in subset.iterrows():
                print(f"  {row['instance_type']}: {row['avg_tokens_per_second']:.2f} ± {row['std_tokens_per_second']:.2f} tokens/s")
            
            # 计算性能差异
            if len(subset) == 2:
                values = subset['avg_tokens_per_second'].values
                if 'c7i.2xlarge' in subset['instance_type'].values and 'c8g.2xlarge' in subset['instance_type'].values:
                    c7i_perf = subset[subset['instance_type'] == 'c7i.2xlarge']['avg_tokens_per_second'].iloc[0]
                    c8g_perf = subset[subset['instance_type'] == 'c8g.2xlarge']['avg_tokens_per_second'].iloc[0]
                    
                    if c7i_perf > c8g_perf:
                        improvement = ((c7i_perf - c8g_perf) / c8g_perf) * 100
                        print(f"  → c7i.2xlarge is {improvement:.1f}% faster than c8g.2xlarge")
                    else:
                        improvement = ((c8g_perf - c7i_perf) / c7i_perf) * 100
                        print(f"  → c8g.2xlarge is {improvement:.1f}% faster than c7i.2xlarge")
        
        return df
    
    def compare_throughput(self):
        """比较吞吐量性能"""
        print("\n=== Throughput Performance Comparison ===")
        
        comparison_data = []
        
        for instance_type, data in self.results.items():
            throughput_data = data.get('throughput_benchmark', {})
            
            for batch_size, stats in throughput_data.items():
                comparison_data.append({
                    'instance_type': instance_type,
                    'batch_size': batch_size,
                    'avg_throughput_tokens_per_second': stats['avg_throughput_tokens_per_second']
                })
        
        if not comparison_data:
            print("No throughput data found")
            return
        
        df = pd.DataFrame(comparison_data)
        
        # 按batch size分组比较
        for batch_size in df['batch_size'].unique():
            print(f"\nBatch Size: {batch_size}")
            subset = df[df['batch_size'] == batch_size]
            
            for _, row in subset.iterrows():
                print(f"  {row['instance_type']}: {row['avg_throughput_tokens_per_second']:.2f} tokens/s")
            
            # 计算性能差异
            if len(subset) == 2:
                if 'c7i.2xlarge' in subset['instance_type'].values and 'c8g.2xlarge' in subset['instance_type'].values:
                    c7i_perf = subset[subset['instance_type'] == 'c7i.2xlarge']['avg_throughput_tokens_per_second'].iloc[0]
                    c8g_perf = subset[subset['instance_type'] == 'c8g.2xlarge']['avg_throughput_tokens_per_second'].iloc[0]
                    
                    if c7i_perf > c8g_perf:
                        improvement = ((c7i_perf - c8g_perf) / c8g_perf) * 100
                        print(f"  → c7i.2xlarge is {improvement:.1f}% faster than c8g.2xlarge")
                    else:
                        improvement = ((c8g_perf - c7i_perf) / c7i_perf) * 100
                        print(f"  → c8g.2xlarge is {improvement:.1f}% faster than c7i.2xlarge")
        
        return df
    
    def compare_memory_usage(self):
        """比较内存使用"""
        print("\n=== Memory Usage Comparison ===")
        
        for instance_type, data in self.results.items():
            memory_data = data.get('memory_usage', {})
            system_info = data.get('system_info', {})
            
            print(f"\n{instance_type}:")
            print(f"  Total Memory: {system_info.get('memory_total_gb', 'N/A')} GB")
            print(f"  Used Memory: {memory_data.get('system_memory_used_gb', 'N/A'):.2f} GB")
            print(f"  Memory Usage: {memory_data.get('system_memory_percent', 'N/A'):.1f}%")
            print(f"  CPU Cores: {system_info.get('cpu_count', 'N/A')} physical, {system_info.get('cpu_count_logical', 'N/A')} logical")
    
    def compare_load_times(self):
        """比较模型加载时间"""
        print("\n=== Model Load Time Comparison ===")
        
        for instance_type, data in self.results.items():
            load_time = data.get('model_load_time', 'N/A')
            print(f"{instance_type}: {load_time:.2f}s")
        
        # 计算差异
        if len(self.results) == 2:
            load_times = {k: v.get('model_load_time', 0) for k, v in self.results.items()}
            instance_types = list(load_times.keys())
            
            if len(instance_types) == 2:
                faster_instance = min(load_times, key=load_times.get)
                slower_instance = max(load_times, key=load_times.get)
                
                if load_times[faster_instance] != load_times[slower_instance]:
                    improvement = ((load_times[slower_instance] - load_times[faster_instance]) / load_times[slower_instance]) * 100
                    print(f"→ {faster_instance} loads {improvement:.1f}% faster than {slower_instance}")
    
    def generate_summary_report(self):
        """生成总结报告"""
        print("\n" + "=" * 60)
        print("PERFORMANCE SUMMARY REPORT")
        print("=" * 60)
        
        # 系统信息对比
        print("\nSystem Specifications:")
        for instance_type, data in self.results.items():
            system_info = data.get('system_info', {})
            print(f"\n{instance_type}:")
            print(f"  Processor: {system_info.get('processor', 'N/A')}")
            print(f"  Architecture: {system_info.get('architecture', ['N/A'])[0]}")
            print(f"  CPU Cores: {system_info.get('cpu_count', 'N/A')} physical")
            print(f"  Memory: {system_info.get('memory_total_gb', 'N/A')} GB")
            print(f"  PyTorch: {system_info.get('pytorch_version', 'N/A')}")
        
        # 性能对比
        self.compare_load_times()
        self.compare_inference_performance()
        self.compare_throughput()
        self.compare_memory_usage()
        
        # 推荐
        print("\n=== Recommendations ===")
        if len(self.results) >= 2:
            print("Based on the benchmark results:")
            print("• For inference workloads, consider the instance with higher tokens/second")
            print("• For batch processing, evaluate throughput performance at your target batch size")
            print("• Consider cost-performance ratio for your specific use case")
            print("• c8g instances (Graviton) typically offer better price-performance for CPU workloads")
            print("• c7i instances (Intel) may have better single-thread performance for some workloads")
    
    def save_comparison_report(self, filename="benchmark_comparison_report.txt"):
        """保存比较报告到文件"""
        import sys
        from io import StringIO
        
        # 重定向stdout到字符串
        old_stdout = sys.stdout
        sys.stdout = captured_output = StringIO()
        
        # 生成报告
        self.generate_summary_report()
        
        # 恢复stdout
        sys.stdout = old_stdout
        
        # 保存到文件
        with open(filename, 'w') as f:
            f.write(captured_output.getvalue())
        
        print(f"Comparison report saved to: {filename}")

def main():
    parser = argparse.ArgumentParser(description="Analyze Qwen3 benchmark results")
    parser.add_argument("--pattern", default="qwen3_benchmark_*.json",
                       help="File pattern for benchmark results")
    parser.add_argument("--output", default="benchmark_comparison_report.txt",
                       help="Output filename for comparison report")
    
    args = parser.parse_args()
    
    analyzer = BenchmarkAnalyzer()
    
    # 加载结果
    num_files = analyzer.load_results(args.pattern)
    
    if num_files == 0:
        print("No benchmark result files found!")
        print(f"Looking for pattern: {args.pattern}")
        return
    
    # 生成分析报告
    analyzer.generate_summary_report()
    
    # 保存报告
    analyzer.save_comparison_report(args.output)

if __name__ == "__main__":
    main()
