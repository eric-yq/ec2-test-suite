package com.example;

import org.apache.commons.crypto.cipher.CryptoCipher;
import org.apache.commons.crypto.cipher.CryptoCipherFactory;
import org.apache.commons.crypto.utils.Utils;
import org.fusesource.leveldbjni.JniDBFactory;
import org.iq80.leveldb.DB;
import org.iq80.leveldb.Options;
import org.xerial.snappy.Snappy;

import javax.crypto.spec.SecretKeySpec;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Properties;

/**
 * NativeLibraryDemo - 演示各种native库的使用
 */
public class NativeLibraryDemo {
    
    /**
     * 演示Snappy压缩库
     */
    public void demonstrateSnappy() throws IOException {
        System.out.println("=== Snappy Compression Demo ===");
        
        String originalText = "This is a sample text for compression using Snappy library. " +
                             "Snappy is a fast compression/decompression library developed by Google.";
        
        // 压缩
        byte[] compressed = Snappy.compress(originalText.getBytes(StandardCharsets.UTF_8));
        System.out.println("Original size: " + originalText.length() + " bytes");
        System.out.println("Compressed size: " + compressed.length + " bytes");
        System.out.println("Compression ratio: " + 
                          String.format("%.2f%%", (1.0 - (double)compressed.length / originalText.length()) * 100));
        
        // 解压缩
        byte[] decompressed = Snappy.uncompress(compressed);
        String decompressedText = new String(decompressed, StandardCharsets.UTF_8);
        System.out.println("Decompressed text matches original: " + originalText.equals(decompressedText));
        System.out.println();
    }
    
    /**
     * 演示Apache Commons Crypto
     */
    public void demonstrateCommonsCrypto() throws Exception {
        System.out.println("=== Apache Commons Crypto Demo ===");
        
        String plainText = "Hello, this is a secret message!";
        String algorithm = "AES/CTR/NoPadding";
        
        // 创建密钥
        byte[] key = "1234567890123456".getBytes(StandardCharsets.UTF_8); // 16 bytes for AES-128
        SecretKeySpec secretKey = new SecretKeySpec(key, "AES");
        
        // 初始化向量
        byte[] iv = new byte[16];
        for (int i = 0; i < iv.length; i++) {
            iv[i] = (byte) i;
        }
        
        Properties properties = new Properties();
        
        // 加密
        try (CryptoCipher cipher = Utils.getCipherInstance(algorithm, properties)) {
            cipher.init(javax.crypto.Cipher.ENCRYPT_MODE, secretKey, 
                       new javax.crypto.spec.IvParameterSpec(iv));
            
            byte[] input = plainText.getBytes(StandardCharsets.UTF_8);
            byte[] encrypted = new byte[input.length];
            cipher.doFinal(input, 0, input.length, encrypted, 0);
            
            System.out.println("Original text: " + plainText);
            System.out.println("Encrypted (hex): " + bytesToHex(encrypted));
            
            // 解密
            cipher.init(javax.crypto.Cipher.DECRYPT_MODE, secretKey, 
                       new javax.crypto.spec.IvParameterSpec(iv));
            
            byte[] decrypted = new byte[encrypted.length];
            cipher.doFinal(encrypted, 0, encrypted.length, decrypted, 0);
            
            String decryptedText = new String(decrypted, StandardCharsets.UTF_8);
            System.out.println("Decrypted text: " + decryptedText);
            System.out.println("Decryption successful: " + plainText.equals(decryptedText));
        }
        System.out.println();
    }
    
    /**
     * 演示LevelDB JNI
     */
    public void demonstrateLevelDB() throws IOException {
        System.out.println("=== LevelDB JNI Demo ===");
        
        // 创建临时数据库目录
        File dbDir = new File("/tmp/leveldb-demo-" + System.currentTimeMillis());
        dbDir.mkdirs();
        dbDir.deleteOnExit();
        
        Options options = new Options();
        options.createIfMissing(true);
        
        try (DB db = JniDBFactory.factory.open(dbDir, options)) {
            // 写入数据
            String[] keys = {"user:1", "user:2", "user:3"};
            String[] values = {"Alice", "Bob", "Charlie"};
            
            for (int i = 0; i < keys.length; i++) {
                db.put(keys[i].getBytes(), values[i].getBytes());
                System.out.println("Stored: " + keys[i] + " -> " + values[i]);
            }
            
            // 读取数据
            System.out.println("\nReading data:");
            for (String key : keys) {
                byte[] value = db.get(key.getBytes());
                if (value != null) {
                    System.out.println("Retrieved: " + key + " -> " + new String(value));
                }
            }
            
            // 删除数据
            db.delete("user:2".getBytes());
            System.out.println("\nAfter deleting user:2:");
            
            for (String key : keys) {
                byte[] value = db.get(key.getBytes());
                if (value != null) {
                    System.out.println("Retrieved: " + key + " -> " + new String(value));
                } else {
                    System.out.println("Key not found: " + key);
                }
            }
        }
        
        // 清理
        deleteDirectory(dbDir);
        System.out.println();
    }
    
    /**
     * 演示自定义native库
     */
    public void demonstrateCustomNative() {
        System.out.println("=== Custom Native Library Demo ===");
        
        // 测试加法
        long result1 = MathUtils.add(100, 200);
        System.out.println("100 + 200 = " + result1);
        
        // 测试平方根
        double result2 = MathUtils.sqrt(16.0);
        System.out.println("sqrt(16.0) = " + result2);
        
        // 测试阶乘
        long result3 = MathUtils.factorial(5);
        System.out.println("5! = " + result3);
        
        // 测试字符串处理
        String result4 = MathUtils.processString("Hello Native World");
        System.out.println("String processing result: " + result4);
        
        System.out.println();
    }
    
    // 辅助方法
    private String bytesToHex(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (byte b : bytes) {
            result.append(String.format("%02x", b));
        }
        return result.toString();
    }
    
    private void deleteDirectory(File dir) {
        if (dir.isDirectory()) {
            File[] files = dir.listFiles();
            if (files != null) {
                for (File file : files) {
                    deleteDirectory(file);
                }
            }
        }
        dir.delete();
    }
}
