package com.example.demo;

/**
 * 数学工具类 - 调用 native library
 */
public class MathUtils {
    
    static {
        // 加载 native library
        NativeLibraryLoader.loadLibraryFromResources("mathutils");
    }
    
    /**
     * 计算最大公约数
     */
    public static native long gcd(long a, long b);
    
    /**
     * 计算斐波那契数列第n项
     */
    public static native long fibonacci(int n);
    
    /**
     * 判断是否为质数
     */
    public static native boolean isPrime(long n);
    
    /**
     * 演示方法
     */
    public static void demo() {
        System.out.println("=== Math Utils Demo ===");
        
        // 测试最大公约数
        long a = 48, b = 18;
        System.out.printf("GCD of %d and %d: %d%n", a, b, gcd(a, b));
        
        // 测试斐波那契数列
        int n = 10;
        System.out.printf("Fibonacci(%d): %d%n", n, fibonacci(n));
        
        // 测试质数判断
        long[] testNumbers = {17, 25, 97, 100};
        for (long num : testNumbers) {
            System.out.printf("%d is prime: %b%n", num, isPrime(num));
        }
        
        System.out.println();
    }
}
