package com.example;

/**
 * NativeDemoApplication - 主应用程序入口
 */
public class NativeDemoApplication {
    
    public static void main(String[] args) {
        System.out.println("Java Native Library Demo Application");
        System.out.println("====================================");
        
        NativeLibraryDemo demo = new NativeLibraryDemo();
        
        try {
            // 演示各种native库的使用
            demo.demonstrateSnappy();
            demo.demonstrateCommonsCrypto();
            demo.demonstrateLevelDB();
            demo.demonstrateCustomNative();
            
            System.out.println("All demos completed successfully!");
            
        } catch (Exception e) {
            System.err.println("Error during demo execution: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }
}
