package com.example.demo;

import com.sun.jna.Library;
import com.sun.jna.Native;
import com.sun.jna.Platform;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;

/**
 * 演示自定义 native library 的调用
 * 包含 3 个自定义的 .so 文件
 */
public class CustomNativeLibraryDemo {
    
    private static final Logger logger = LoggerFactory.getLogger(CustomNativeLibraryDemo.class);
    
    // JNA 接口定义
    public interface MathLibrary extends Library {
        int add(int a, int b);
        int multiply(int a, int b);
        double sqrt(double x);
    }
    
    public interface StringLibrary extends Library {
        int string_length(String str);
        String reverse_string(String str);
        String to_uppercase(String str);
    }
    
    public interface SystemLibrary extends Library {
        long get_current_timestamp();
        int get_process_id();
        String get_system_info();
    }
    
    private MathLibrary mathLib;
    private StringLibrary stringLib;
    private SystemLibrary systemLib;
    
    // 共享的临时目录
    private static File sharedTempDir = null;
    
    public CustomNativeLibraryDemo() {
        loadNativeLibraries();
    }
    
    /**
     * 加载自定义 native libraries
     */
    private void loadNativeLibraries() {
        try {
            // 创建共享的临时目录
            if (sharedTempDir == null) {
                sharedTempDir = new File(System.getProperty("java.io.tmpdir"), "native_libs_" + System.currentTimeMillis());
                if (!sharedTempDir.exists()) {
                    sharedTempDir.mkdirs();
                }
                sharedTempDir.deleteOnExit();
            }
            
            // 从 resources 中提取 .so 文件到共享临时目录
            extractNativeLibrary("libmath_ops.so");
            extractNativeLibrary("libstring_ops.so");
            extractNativeLibrary("libsystem_ops.so");
            
            // 设置 JNA 库路径
            String tempDirPath = sharedTempDir.getAbsolutePath();
            String currentPath = System.getProperty("jna.library.path");
            if (currentPath == null) {
                System.setProperty("jna.library.path", tempDirPath);
            } else if (!currentPath.contains(tempDirPath)) {
                System.setProperty("jna.library.path", currentPath + File.pathSeparator + tempDirPath);
            }
            
            logger.info("JNA library path set to: {}", System.getProperty("jna.library.path"));
            
            // 加载 libraries（使用库名，不带 lib 前缀和 .so 后缀）
            mathLib = Native.load("math_ops", MathLibrary.class);
            stringLib = Native.load("string_ops", StringLibrary.class);
            systemLib = Native.load("system_ops", SystemLibrary.class);
            
            logger.info("All custom native libraries loaded successfully");
            
        } catch (Exception e) {
            logger.error("Failed to load custom native libraries", e);
            throw new RuntimeException("Native library loading failed", e);
        }
    }
    
    /**
     * 从 JAR 中提取 native library 到共享临时目录
     */
    private void extractNativeLibrary(String libraryName) throws Exception {
        String resourcePath = "/native/" + libraryName;
        
        try (InputStream is = getClass().getResourceAsStream(resourcePath)) {
            if (is == null) {
                throw new RuntimeException("Native library not found in resources: " + resourcePath);
            }
            
            // 创建临时文件在共享目录中
            File tempFile = new File(sharedTempDir, libraryName);
            tempFile.deleteOnExit();
            
            // 复制到临时文件
            Files.copy(is, tempFile.toPath(), StandardCopyOption.REPLACE_EXISTING);
            
            // 设置可执行权限
            tempFile.setExecutable(true);
            tempFile.setReadable(true);
            
            logger.info("Extracted native library: {} to {}", libraryName, tempFile.getAbsolutePath());
        }
    }
    
    /**
     * 演示所有自定义 native libraries
     */
    public void demonstrateCustomLibraries() {
        demonstrateMathLibrary();
        demonstrateStringLibrary();
        demonstrateSystemLibrary();
    }
    
    /**
     * 演示数学运算库
     */
    private void demonstrateMathLibrary() {
        try {
            logger.info("=== Math Library Demo ===");
            
            int a = 15, b = 25;
            int sum = mathLib.add(a, b);
            int product = mathLib.multiply(a, b);
            double sqrtResult = mathLib.sqrt(144.0);
            
            logger.info("Math operations:");
            logger.info("  {} + {} = {}", a, b, sum);
            logger.info("  {} * {} = {}", a, b, product);
            logger.info("  sqrt(144.0) = {}", sqrtResult);
            logger.info("Math library is working correctly");
            
        } catch (Exception e) {
            logger.error("Math library demonstration failed", e);
            throw new RuntimeException("Math library demo failed", e);
        }
    }
    
    /**
     * 演示字符串操作库
     */
    private void demonstrateStringLibrary() {
        try {
            logger.info("=== String Library Demo ===");
            
            String testString = "Hello Native World";
            int length = stringLib.string_length(testString);
            String reversed = stringLib.reverse_string(testString);
            String uppercase = stringLib.to_uppercase(testString);
            
            logger.info("String operations:");
            logger.info("  Original: '{}'", testString);
            logger.info("  Length: {}", length);
            logger.info("  Reversed: '{}'", reversed);
            logger.info("  Uppercase: '{}'", uppercase);
            logger.info("String library is working correctly");
            
        } catch (Exception e) {
            logger.error("String library demonstration failed", e);
            throw new RuntimeException("String library demo failed", e);
        }
    }
    
    /**
     * 演示系统信息库
     */
    private void demonstrateSystemLibrary() {
        try {
            logger.info("=== System Library Demo ===");
            
            long timestamp = systemLib.get_current_timestamp();
            int processId = systemLib.get_process_id();
            String systemInfo = systemLib.get_system_info();
            
            logger.info("System information:");
            logger.info("  Current timestamp: {}", timestamp);
            logger.info("  Process ID: {}", processId);
            logger.info("  System info: {}", systemInfo);
            logger.info("System library is working correctly");
            
        } catch (Exception e) {
            logger.error("System library demonstration failed", e);
            throw new RuntimeException("System library demo failed", e);
        }
    }
}
