package com.example.demo;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Native Demo Application - 演示 Java 调用 native libraries
 * 仅支持 x86_64 架构
 */
public class NativeDemoApplication {
    
    private static final Logger logger = LoggerFactory.getLogger(NativeDemoApplication.class);
    
    public static void main(String[] args) {
        logger.info("Starting Native Demo Application (x86_64 only)");
        
        try {
            // 演示第三方组件调用
            ThirdPartyLibraryDemo thirdPartyDemo = new ThirdPartyLibraryDemo();
            thirdPartyDemo.demonstrateSnappy();
            thirdPartyDemo.demonstrateCommonsCrypto();
            thirdPartyDemo.demonstrateRocksDB();
            
            // 演示自定义 native library 调用
            CustomNativeLibraryDemo customDemo = new CustomNativeLibraryDemo();
            customDemo.demonstrateCustomLibraries();
            
            logger.info("All demonstrations completed successfully");
            
        } catch (Exception e) {
            logger.error("Error during demonstration", e);
            System.exit(1);
        }
    }
}
