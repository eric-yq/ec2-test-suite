package com.example.demo;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;

/**
 * 多架构 Native Library 加载工具类
 */
public class NativeLibraryLoader {
    
    private static final String OS_NAME = System.getProperty("os.name").toLowerCase();
    private static final String OS_ARCH = System.getProperty("os.arch").toLowerCase();
    
    /**
     * 获取当前平台的架构标识符
     */
    public static String getPlatformIdentifier() {
        String osPrefix;
        if (OS_NAME.contains("linux")) {
            osPrefix = "linux";
        } else if (OS_NAME.contains("windows")) {
            osPrefix = "windows";
        } else if (OS_NAME.contains("mac")) {
            osPrefix = "darwin";
        } else {
            osPrefix = "unknown";
        }
        
        String archSuffix;
        if (OS_ARCH.contains("amd64") || OS_ARCH.contains("x86_64")) {
            archSuffix = "x86_64";
        } else if (OS_ARCH.contains("aarch64") || OS_ARCH.contains("arm64")) {
            archSuffix = "aarch64";
        } else if (OS_ARCH.contains("arm")) {
            archSuffix = "arm";
        } else {
            archSuffix = OS_ARCH;
        }
        
        return osPrefix + "-" + archSuffix;
    }
    
    /**
     * 从 resources 加载 native library
     */
    public static void loadLibraryFromResources(String libraryName) {
        String platformId = getPlatformIdentifier();
        String resourcePath = "/native/" + platformId + "/lib" + libraryName + ".so";
        
        System.out.println("Loading native library: " + libraryName);
        System.out.println("Platform identifier: " + platformId);
        System.out.println("Resource path: " + resourcePath);
        
        try (InputStream is = NativeLibraryLoader.class.getResourceAsStream(resourcePath)) {
            if (is == null) {
                // 如果从 resources 加载失败，尝试使用系统加载
                System.out.println("Library not found in resources, trying system load...");
                System.loadLibrary(libraryName);
                return;
            }
            
            // 创建临时文件
            Path tempFile = Files.createTempFile("lib" + libraryName, ".so");
            tempFile.toFile().deleteOnExit();
            
            // 复制到临时文件
            Files.copy(is, tempFile, StandardCopyOption.REPLACE_EXISTING);
            
            // 加载临时文件
            System.load(tempFile.toAbsolutePath().toString());
            System.out.println("Successfully loaded " + libraryName + " from resources");
            
        } catch (IOException e) {
            System.err.println("Failed to load library from resources: " + e.getMessage());
            // 回退到系统加载
            try {
                System.loadLibrary(libraryName);
                System.out.println("Successfully loaded " + libraryName + " from system");
            } catch (UnsatisfiedLinkError ule) {
                throw new RuntimeException("Failed to load native library: " + libraryName, ule);
            }
        } catch (UnsatisfiedLinkError e) {
            System.err.println("Failed to load library: " + e.getMessage());
            throw e;
        }
    }
    
    /**
     * 检查 native library 是否可用
     */
    public static boolean isLibraryAvailable(String libraryName) {
        try {
            loadLibraryFromResources(libraryName);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
    
    /**
     * 打印系统信息
     */
    public static void printSystemInfo() {
        System.out.println("=== System Information ===");
        System.out.println("OS Name: " + OS_NAME);
        System.out.println("OS Arch: " + OS_ARCH);
        System.out.println("Platform ID: " + getPlatformIdentifier());
        System.out.println("Java Library Path: " + System.getProperty("java.library.path"));
        System.out.println();
    }
}
