package com.example;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;

/**
 * MathUtils - 调用自定义native库的工具类
 */
public class MathUtils {
    
    static {
        try {
            loadNativeLibrary();
        } catch (Exception e) {
            throw new RuntimeException("Failed to load native library", e);
        }
    }
    
    /**
     * 从JAR中加载native库
     */
    private static void loadNativeLibrary() throws IOException {
        String libraryName = "libmathutils.so";
        
        // 尝试从classpath加载
        InputStream inputStream = MathUtils.class.getClassLoader().getResourceAsStream(libraryName);
        if (inputStream == null) {
            throw new IOException("Native library not found in classpath: " + libraryName);
        }
        
        // 创建临时文件
        File tempFile = File.createTempFile("libmathutils", ".so");
        tempFile.deleteOnExit();
        
        // 复制库文件到临时位置
        try (FileOutputStream outputStream = new FileOutputStream(tempFile)) {
            byte[] buffer = new byte[8192];
            int bytesRead;
            while ((bytesRead = inputStream.read(buffer)) != -1) {
                outputStream.write(buffer, 0, bytesRead);
            }
        }
        
        // 加载库
        System.load(tempFile.getAbsolutePath());
    }
    
    // Native方法声明
    public static native long add(long a, long b);
    public static native double sqrt(double value);
    public static native long factorial(int n);
    public static native String processString(String input);
}
