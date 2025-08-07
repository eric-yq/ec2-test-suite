package com.example.demo;

/**
 * 主应用程序类
 */
public class NativeDemoApplication {
    
    public static void main(String[] args) {
        System.out.println("========================================");
        System.out.println("Java Native Demo Multi-Architecture");
        System.out.println("========================================");
        System.out.println();
        
        try {
            // 演示字节码类型的第三方组件
            ThirdPartyDemo.demoBytecodeLibraries();
            
            // 演示包含 native library 的第三方组件
            ThirdPartyDemo.demoNativeLibraries();
            
            // 演示自定义的 native libraries
            System.out.println("=== Custom Native Libraries Demo ===");
            
            // 数学工具演示
            MathUtils.demo();
            
            // 字符串工具演示
            StringUtils.demo();
            
            // 系统信息演示
            SystemInfo.demo();
            
        } catch (UnsatisfiedLinkError e) {
            System.err.println("Native library loading error: " + e.getMessage());
            System.err.println("Please make sure native libraries are built and available in java.library.path");
            System.err.println("Current java.library.path: " + System.getProperty("java.library.path"));
        } catch (Exception e) {
            System.err.println("Application error: " + e.getMessage());
            e.printStackTrace();
        }
        
        System.out.println("========================================");
        System.out.println("Demo completed successfully!");
        System.out.println("========================================");
    }
}
