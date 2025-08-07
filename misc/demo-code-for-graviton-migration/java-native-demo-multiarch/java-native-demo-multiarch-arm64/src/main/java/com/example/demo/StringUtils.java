package com.example.demo;

/**
 * 字符串工具类 - 调用 native library
 */
public class StringUtils {
    
    static {
        // 加载 native library
        NativeLibraryLoader.loadLibraryFromResources("stringutils");
    }
    
    /**
     * 反转字符串
     */
    public static native String reverseString(String input);
    
    /**
     * 转换为大写
     */
    public static native String toUpperCase(String input);
    
    /**
     * 计算字符出现次数
     */
    public static native int countChar(String input, char ch);
    
    /**
     * 检查是否为回文
     */
    public static native boolean isPalindrome(String input);
    
    /**
     * 演示方法
     */
    public static void demo() {
        System.out.println("=== String Utils Demo ===");
        
        String testString = "Hello World";
        System.out.printf("Original: %s%n", testString);
        System.out.printf("Reversed: %s%n", reverseString(testString));
        System.out.printf("Upper Case: %s%n", toUpperCase(testString));
        System.out.printf("Count 'l': %d%n", countChar(testString, 'l'));
        
        // 测试回文
        String[] palindromes = {"racecar", "A man a plan a canal Panama", "hello"};
        for (String str : palindromes) {
            System.out.printf("'%s' is palindrome: %b%n", str, isPalindrome(str));
        }
        
        System.out.println();
    }
}
