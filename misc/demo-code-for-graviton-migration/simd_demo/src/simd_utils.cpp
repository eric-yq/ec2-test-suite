#include "simd_demo.h"
#include <cpuid.h>

void print_performance(const char* name, double time_ms, double speedup) {
    std::cout << std::setw(20) << name << ": " 
              << std::setw(8) << std::fixed << std::setprecision(3) << time_ms << " ms";
    if (speedup > 0.0) {
        std::cout << " (加速比: " << std::setprecision(2) << speedup << "x)";
    }
    std::cout << std::endl;
}

bool check_cpu_support() {
    unsigned int eax, ebx, ecx, edx;
    
    // 检查CPUID支持
    if (__get_cpuid(1, &eax, &ebx, &ecx, &edx)) {
        return true;
    }
    return false;
}

void print_cpu_features() {
    std::cout << "CPU特性检测:" << std::endl;
    
    unsigned int eax, ebx, ecx, edx;
    
    // 检查基本特性
    if (__get_cpuid(1, &eax, &ebx, &ecx, &edx)) {
        std::cout << "  SSE:     " << ((edx & bit_SSE) ? "支持" : "不支持") << std::endl;
        std::cout << "  SSE2:    " << ((edx & bit_SSE2) ? "支持" : "不支持") << std::endl;
        std::cout << "  SSE3:    " << ((ecx & bit_SSE3) ? "支持" : "不支持") << std::endl;
        std::cout << "  SSSE3:   " << ((ecx & bit_SSSE3) ? "支持" : "不支持") << std::endl;
        std::cout << "  SSE4.1:  " << ((ecx & bit_SSE4_1) ? "支持" : "不支持") << std::endl;
        std::cout << "  SSE4.2:  " << ((ecx & bit_SSE4_2) ? "支持" : "不支持") << std::endl;
        std::cout << "  AVX:     " << ((ecx & bit_AVX) ? "支持" : "不支持") << std::endl;
    }
    
    // 检查扩展特性
    if (__get_cpuid_count(7, 0, &eax, &ebx, &ecx, &edx)) {
        std::cout << "  AVX2:    " << ((ebx & bit_AVX2) ? "支持" : "不支持") << std::endl;
        std::cout << "  AVX512F: " << ((ebx & bit_AVX512F) ? "支持" : "不支持") << std::endl;
        std::cout << "  AVX512DQ:" << ((ebx & bit_AVX512DQ) ? "支持" : "不支持") << std::endl;
        std::cout << "  AVX512BW:" << ((ebx & bit_AVX512BW) ? "支持" : "不支持") << std::endl;
        std::cout << "  AVX512VL:" << ((ebx & bit_AVX512VL) ? "支持" : "不支持") << std::endl;
    }
}
