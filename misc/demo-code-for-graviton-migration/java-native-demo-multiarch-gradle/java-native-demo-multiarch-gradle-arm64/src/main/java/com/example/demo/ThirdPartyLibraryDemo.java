package com.example.demo;

import org.apache.commons.crypto.cipher.CryptoCipher;
import org.apache.commons.crypto.cipher.CryptoCipherFactory;
import org.apache.commons.crypto.utils.Utils;
import org.rocksdb.Options;
import org.rocksdb.RocksDB;
import org.rocksdb.RocksDBException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.xerial.snappy.Snappy;

import javax.crypto.spec.SecretKeySpec;
import java.io.File;
import java.nio.charset.StandardCharsets;
import java.util.Properties;

/**
 * 演示第三方 native library 的使用
 * 包含字节码组件和 .so 文件组件
 */
public class ThirdPartyLibraryDemo {
    
    private static final Logger logger = LoggerFactory.getLogger(ThirdPartyLibraryDemo.class);
    
    /**
     * 演示 Snappy 压缩库（字节码 + native .so）
     */
    public void demonstrateSnappy() {
        try {
            logger.info("=== Snappy Compression Demo ===");
            
            String originalText = "This is a test string for Snappy compression demonstration. " +
                                "Snappy is a fast compression/decompression library developed by Google. " +
                                "It aims for very high speeds and reasonable compression.";
            
            byte[] originalBytes = originalText.getBytes(StandardCharsets.UTF_8);
            logger.info("Original text length: {} bytes", originalBytes.length);
            
            // 压缩
            byte[] compressed = Snappy.compress(originalBytes);
            logger.info("Compressed length: {} bytes", compressed.length);
            logger.info("Compression ratio: {:.2f}%", 
                       (1.0 - (double) compressed.length / originalBytes.length) * 100);
            
            // 解压缩
            byte[] decompressed = Snappy.uncompress(compressed);
            String decompressedText = new String(decompressed, StandardCharsets.UTF_8);
            
            logger.info("Decompression successful: {}", originalText.equals(decompressedText));
            logger.info("Snappy native library is working correctly");
            
        } catch (Exception e) {
            logger.error("Snappy demonstration failed", e);
            throw new RuntimeException("Snappy demo failed", e);
        }
    }
    
    /**
     * 演示 Apache Commons Crypto（字节码 + native .so）
     */
    public void demonstrateCommonsCrypto() {
        try {
            logger.info("=== Apache Commons Crypto Demo ===");
            
            String plainText = "Hello, this is a secret message for encryption!";
            byte[] input = plainText.getBytes(StandardCharsets.UTF_8);
            
            // 创建加密器 - 先尝试 OpenSSL，失败则使用 JCE
            Properties properties = new Properties();
            String transform = "AES/CTR/NoPadding";
            CryptoCipher cipher = null;
            
            try {
                // 尝试使用 OpenSSL native 实现
                properties.setProperty(CryptoCipherFactory.CLASSES_KEY, 
                                     CryptoCipherFactory.CipherProvider.OPENSSL.getClassName());
                cipher = Utils.getCipherInstance(transform, properties);
                logger.info("Using OpenSSL native implementation");
            } catch (Exception e) {
                logger.warn("OpenSSL native implementation failed, falling back to JCE: {}", e.getMessage());
                // 降级到 JCE 实现
                properties.setProperty(CryptoCipherFactory.CLASSES_KEY, 
                                     CryptoCipherFactory.CipherProvider.JCE.getClassName());
                cipher = Utils.getCipherInstance(transform, properties);
                logger.info("Using JCE implementation");
            }
            
            // 密钥
            byte[] key = "1234567890123456".getBytes(StandardCharsets.UTF_8); // 16 bytes for AES-128
            SecretKeySpec secretKeySpec = new SecretKeySpec(key, "AES");
            
            // IV
            byte[] iv = new byte[16];
            for (int i = 0; i < iv.length; i++) {
                iv[i] = (byte) i;
            }
            
            // 加密
            cipher.init(javax.crypto.Cipher.ENCRYPT_MODE, secretKeySpec, 
                       new javax.crypto.spec.IvParameterSpec(iv));
            byte[] encrypted = new byte[input.length];
            cipher.doFinal(input, 0, input.length, encrypted, 0);
            
            logger.info("Original text: {}", plainText);
            logger.info("Encrypted length: {} bytes", encrypted.length);
            
            // 解密
            cipher.init(javax.crypto.Cipher.DECRYPT_MODE, secretKeySpec, 
                       new javax.crypto.spec.IvParameterSpec(iv));
            byte[] decrypted = new byte[encrypted.length];
            cipher.doFinal(encrypted, 0, encrypted.length, decrypted, 0);
            
            String decryptedText = new String(decrypted, StandardCharsets.UTF_8);
            logger.info("Decrypted text: {}", decryptedText);
            logger.info("Encryption/Decryption successful: {}", plainText.equals(decryptedText));
            logger.info("Commons Crypto native library is working correctly");
            
            cipher.close();
            
        } catch (Exception e) {
            logger.error("Commons Crypto demonstration failed", e);
            throw new RuntimeException("Commons Crypto demo failed", e);
        }
    }
    
    /**
     * 演示 RocksDB（.so 文件组件）
     */
    public void demonstrateRocksDB() {
        RocksDB db = null;
        try {
            logger.info("=== RocksDB Demo ===");
            
            // 加载 RocksDB native library
            RocksDB.loadLibrary();
            
            // 创建临时数据库目录
            String dbPath = "/tmp/rocksdb-demo-" + System.currentTimeMillis();
            new File(dbPath).mkdirs();
            
            // 配置选项
            Options options = new Options();
            options.setCreateIfMissing(true);
            
            // 打开数据库
            db = RocksDB.open(options, dbPath);
            logger.info("RocksDB opened successfully at: {}", dbPath);
            
            // 写入数据
            String key1 = "user:1001";
            String value1 = "John Doe";
            db.put(key1.getBytes(), value1.getBytes());
            
            String key2 = "user:1002";
            String value2 = "Jane Smith";
            db.put(key2.getBytes(), value2.getBytes());
            
            logger.info("Data written to RocksDB");
            
            // 读取数据
            byte[] retrievedValue1 = db.get(key1.getBytes());
            byte[] retrievedValue2 = db.get(key2.getBytes());
            
            if (retrievedValue1 != null && retrievedValue2 != null) {
                logger.info("Retrieved: {} = {}", key1, new String(retrievedValue1));
                logger.info("Retrieved: {} = {}", key2, new String(retrievedValue2));
                logger.info("RocksDB native library is working correctly");
            } else {
                throw new RuntimeException("Failed to retrieve data from RocksDB");
            }
            
            // 清理
            options.close();
            
        } catch (RocksDBException e) {
            logger.error("RocksDB demonstration failed", e);
            throw new RuntimeException("RocksDB demo failed", e);
        } finally {
            if (db != null) {
                db.close();
            }
        }
    }
}
