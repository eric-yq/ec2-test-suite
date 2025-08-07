package com.example.demo;

/**
 * 系统信息类 - 调用 native library
 */
public class SystemInfo {
    
    static {
        // 加载 native library
        NativeLibraryLoader.loadLibraryFromResources("systeminfo");
    }
    
    /**
     * 获取系统架构
     */
    public static native String getArchitecture();
    
    /**
     * 获取内核版本
     */
    public static native String getKernelVersion();
    
    /**
     * 获取CPU核心数
     */
    public static native int getCpuCores();
    
    /**
     * 获取总内存（MB）
     */
    public static native long getTotalMemoryMB();
    
    /**
     * 获取可用内存（MB）
     */
    public static native long getAvailableMemoryMB();
    
    /**
     * 获取系统负载平均值
     */
    public static native double getLoadAverage();
    
    /**
     * 演示方法
     */
    public static void demo() {
        System.out.println("=== System Info Demo ===");
        System.out.printf("Architecture: %s%n", getArchitecture());
        System.out.printf("Kernel Version: %s%n", getKernelVersion());
        System.out.printf("CPU Cores: %d%n", getCpuCores());
        System.out.printf("Total Memory: %d MB%n", getTotalMemoryMB());
        System.out.printf("Available Memory: %d MB%n", getAvailableMemoryMB());
        System.out.printf("Load Average: %.2f%n", getLoadAverage());
        System.out.println();
    }
}
