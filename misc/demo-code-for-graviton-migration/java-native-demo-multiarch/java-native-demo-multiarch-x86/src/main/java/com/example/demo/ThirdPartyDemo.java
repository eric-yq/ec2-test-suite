package com.example.demo;

import org.apache.commons.codec.binary.Base64;
import org.apache.commons.lang3.StringUtils;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

// 包含 native library 的第三方组件
import org.xerial.snappy.Snappy;
import org.apache.commons.crypto.cipher.CryptoCipher;
import org.apache.commons.crypto.cipher.CryptoCipherFactory;
import org.apache.commons.crypto.utils.Utils;
import net.jpountz.lz4.LZ4Compressor;
import net.jpountz.lz4.LZ4Factory;
import net.jpountz.lz4.LZ4FastDecompressor;

import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.Properties;

/**
 * 第三方组件演示类
 */
public class ThirdPartyDemo {
    
    /**
     * 演示字节码类型的第三方组件
     */
    public static void demoBytecodeLibraries() {
        System.out.println("=== Bytecode Libraries Demo ===");
        
        // Apache Commons Codec - Base64编码
        String originalText = "Hello, World!";
        String encoded = Base64.encodeBase64String(originalText.getBytes());
        String decoded = new String(Base64.decodeBase64(encoded));
        System.out.printf("Original: %s%n", originalText);
        System.out.printf("Base64 Encoded: %s%n", encoded);
        System.out.printf("Base64 Decoded: %s%n", decoded);
        
        // Apache Commons Lang3 - 字符串工具
        String testStr = "  Hello World  ";
        System.out.printf("Original String: '%s'%n", testStr);
        System.out.printf("Trimmed: '%s'%n", StringUtils.trim(testStr));
        System.out.printf("Capitalized: '%s'%n", StringUtils.capitalize(testStr.trim().toLowerCase()));
        System.out.printf("Reversed: '%s'%n", StringUtils.reverse(testStr.trim()));
        
        // Jackson JSON处理
        try {
            ObjectMapper mapper = new ObjectMapper();
            ObjectNode jsonNode = mapper.createObjectNode();
            jsonNode.put("name", "Java Native Demo");
            jsonNode.put("version", "1.0.0");
            jsonNode.put("architecture", "x86_64");
            
            String jsonString = mapper.writeValueAsString(jsonNode);
            System.out.printf("JSON: %s%n", jsonString);
        } catch (Exception e) {
            System.err.println("JSON processing error: " + e.getMessage());
        }
        
        System.out.println();
    }
    
    /**
     * 演示包含 native library 的第三方组件
     */
    public static void demoNativeLibraries() {
        System.out.println("=== Native Libraries Demo ===");
        
        // Snappy 压缩
        try {
            String originalData = "This is a test string for compression. ".repeat(10);
            byte[] originalBytes = originalData.getBytes(StandardCharsets.UTF_8);
            
            // 压缩
            byte[] compressed = Snappy.compress(originalBytes);
            // 解压缩
            byte[] decompressed = Snappy.uncompress(compressed);
            
            System.out.printf("Snappy Compression:%n");
            System.out.printf("  Original size: %d bytes%n", originalBytes.length);
            System.out.printf("  Compressed size: %d bytes%n", compressed.length);
            System.out.printf("  Compression ratio: %.2f%%%n", 
                (1.0 - (double)compressed.length / originalBytes.length) * 100);
            System.out.printf("  Decompressed matches original: %b%n", 
                originalData.equals(new String(decompressed, StandardCharsets.UTF_8)));
            
        } catch (Exception e) {
            System.err.println("Snappy compression error: " + e.getMessage());
        }
        
        // LZ4 压缩
        try {
            String originalData = "LZ4 is a fast compression algorithm. ".repeat(20);
            byte[] originalBytes = originalData.getBytes(StandardCharsets.UTF_8);
            
            LZ4Factory factory = LZ4Factory.fastestInstance();
            LZ4Compressor compressor = factory.fastCompressor();
            LZ4FastDecompressor decompressor = factory.fastDecompressor();
            
            // 压缩
            int maxCompressedLength = compressor.maxCompressedLength(originalBytes.length);
            byte[] compressed = new byte[maxCompressedLength];
            int compressedLength = compressor.compress(originalBytes, 0, originalBytes.length, compressed, 0, maxCompressedLength);
            
            // 解压缩
            byte[] decompressed = new byte[originalBytes.length];
            decompressor.decompress(compressed, 0, decompressed, 0, originalBytes.length);
            
            System.out.printf("LZ4 Compression:%n");
            System.out.printf("  Original size: %d bytes%n", originalBytes.length);
            System.out.printf("  Compressed size: %d bytes%n", compressedLength);
            System.out.printf("  Compression ratio: %.2f%%%n", 
                (1.0 - (double)compressedLength / originalBytes.length) * 100);
            System.out.printf("  Decompressed matches original: %b%n", 
                originalData.equals(new String(decompressed, StandardCharsets.UTF_8)));
            
        } catch (Exception e) {
            System.err.println("LZ4 compression error: " + e.getMessage());
        }
        
        // Apache Commons Crypto - 1.0.0 版本 API
        try {
            String plainText = "Hello, Commons Crypto!";
            byte[] key = "1234567890123456".getBytes(StandardCharsets.UTF_8); // 16 bytes key
            byte[] iv = "1234567890123456".getBytes(StandardCharsets.UTF_8);  // 16 bytes IV
            
            Properties properties = new Properties();
            // 1.0.0 版本使用不同的属性设置
            properties.setProperty("org.apache.commons.crypto.cipher.classes", 
                "org.apache.commons.crypto.cipher.OpenSslCipher");
            
            // 加密
            try (CryptoCipher cipher = Utils.getCipherInstance("AES/CBC/PKCS5Padding", properties)) {
                cipher.init(javax.crypto.Cipher.ENCRYPT_MODE, new SecretKeySpec(key, "AES"), 
                    new javax.crypto.spec.IvParameterSpec(iv));
                
                byte[] input = plainText.getBytes(StandardCharsets.UTF_8);
                // 为 AES 加密预分配足够的空间 (输入长度 + 块大小)
                byte[] encrypted = new byte[input.length + 32]; // 增加缓冲区大小以兼容旧版本
                int encryptedLength = cipher.doFinal(input, 0, input.length, encrypted, 0);
                
                System.out.printf("Commons Crypto AES Encryption (v1.0.0):%n");
                System.out.printf("  Original: %s%n", plainText);
                System.out.printf("  Encrypted length: %d bytes%n", encryptedLength);
                System.out.printf("  Encrypted (Base64): %s%n", 
                    Base64.encodeBase64String(java.util.Arrays.copyOf(encrypted, encryptedLength)));
            }
            
        } catch (Exception e) {
            System.err.println("Commons Crypto error: " + e.getMessage());
        }
        
        System.out.println();
    }
}
