#include <jni.h>
#include <iostream>
#include <cmath>

extern "C" {
    // 计算两个数的和
    JNIEXPORT jlong JNICALL Java_com_example_MathUtils_add(JNIEnv *env, jclass clazz, jlong a, jlong b) {
        return a + b;
    }

    // 计算平方根
    JNIEXPORT jdouble JNICALL Java_com_example_MathUtils_sqrt(JNIEnv *env, jclass clazz, jdouble value) {
        return std::sqrt(value);
    }

    // 计算阶乘
    JNIEXPORT jlong JNICALL Java_com_example_MathUtils_factorial(JNIEnv *env, jclass clazz, jint n) {
        if (n <= 1) return 1;
        long result = 1;
        for (int i = 2; i <= n; i++) {
            result *= i;
        }
        return result;
    }

    // 字符串处理函数
    JNIEXPORT jstring JNICALL Java_com_example_MathUtils_processString(JNIEnv *env, jclass clazz, jstring input) {
        const char* inputStr = env->GetStringUTFChars(input, nullptr);
        std::string result = "Processed: ";
        result += inputStr;
        env->ReleaseStringUTFChars(input, inputStr);
        return env->NewStringUTF(result.c_str());
    }
}
