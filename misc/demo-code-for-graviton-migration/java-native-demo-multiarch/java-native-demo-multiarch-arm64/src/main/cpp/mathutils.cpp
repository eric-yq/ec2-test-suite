#include <jni.h>
#include <cmath>
#include <iostream>

extern "C" {
    // 计算两个数的最大公约数
    JNIEXPORT jlong JNICALL Java_com_example_demo_MathUtils_gcd(JNIEnv *env, jclass clazz, jlong a, jlong b) {
        if (b == 0) return a;
        return Java_com_example_demo_MathUtils_gcd(env, clazz, b, a % b);
    }

    // 计算斐波那契数列
    JNIEXPORT jlong JNICALL Java_com_example_demo_MathUtils_fibonacci(JNIEnv *env, jclass clazz, jint n) {
        if (n <= 1) return n;
        
        long long prev = 0, curr = 1;
        for (int i = 2; i <= n; i++) {
            long long next = prev + curr;
            prev = curr;
            curr = next;
        }
        return curr;
    }

    // 判断是否为质数
    JNIEXPORT jboolean JNICALL Java_com_example_demo_MathUtils_isPrime(JNIEnv *env, jclass clazz, jlong n) {
        if (n <= 1) return JNI_FALSE;
        if (n <= 3) return JNI_TRUE;
        if (n % 2 == 0 || n % 3 == 0) return JNI_FALSE;
        
        for (long long i = 5; i * i <= n; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0) {
                return JNI_FALSE;
            }
        }
        return JNI_TRUE;
    }
}
