package com.example.demo;

import org.junit.Test;
import org.junit.Before;
import static org.junit.Assert.*;

/**
 * Native Demo 测试类
 */
public class NativeDemoTest {
    
    private ThirdPartyLibraryDemo thirdPartyDemo;
    
    @Before
    public void setUp() {
        thirdPartyDemo = new ThirdPartyLibraryDemo();
    }
    
    @Test
    public void testSnappyCompression() {
        // 测试 Snappy 压缩功能
        assertDoesNotThrow(() -> {
            thirdPartyDemo.demonstrateSnappy();
        });
    }
    
    @Test
    public void testCommonsCrypto() {
        // 测试 Commons Crypto 加密功能
        assertDoesNotThrow(() -> {
            thirdPartyDemo.demonstrateCommonsCrypto();
        });
    }
    
    @Test
    public void testRocksDB() {
        // 测试 RocksDB 数据库功能
        assertDoesNotThrow(() -> {
            thirdPartyDemo.demonstrateRocksDB();
        });
    }
    
    @Test
    public void testCustomNativeLibraries() {
        // 测试自定义 native libraries
        assertDoesNotThrow(() -> {
            CustomNativeLibraryDemo customDemo = new CustomNativeLibraryDemo();
            customDemo.demonstrateCustomLibraries();
        });
    }
    
    // 辅助方法：断言不抛出异常
    private void assertDoesNotThrow(Runnable runnable) {
        try {
            runnable.run();
        } catch (Exception e) {
            fail("Expected no exception, but got: " + e.getMessage());
        }
    }
}
