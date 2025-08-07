#include <jni.h>
#include <string>
#include <algorithm>
#include <cctype>

extern "C" {
    // 反转字符串
    JNIEXPORT jstring JNICALL Java_com_example_demo_StringUtils_reverseString(JNIEnv *env, jclass clazz, jstring input) {
        const char* nativeString = env->GetStringUTFChars(input, 0);
        std::string str(nativeString);
        std::reverse(str.begin(), str.end());
        
        env->ReleaseStringUTFChars(input, nativeString);
        return env->NewStringUTF(str.c_str());
    }

    // 转换为大写
    JNIEXPORT jstring JNICALL Java_com_example_demo_StringUtils_toUpperCase(JNIEnv *env, jclass clazz, jstring input) {
        const char* nativeString = env->GetStringUTFChars(input, 0);
        std::string str(nativeString);
        std::transform(str.begin(), str.end(), str.begin(), ::toupper);
        
        env->ReleaseStringUTFChars(input, nativeString);
        return env->NewStringUTF(str.c_str());
    }

    // 计算字符串中字符出现次数
    JNIEXPORT jint JNICALL Java_com_example_demo_StringUtils_countChar(JNIEnv *env, jclass clazz, jstring input, jchar ch) {
        const char* nativeString = env->GetStringUTFChars(input, 0);
        std::string str(nativeString);
        int count = 0;
        
        for (char c : str) {
            if (c == (char)ch) {
                count++;
            }
        }
        
        env->ReleaseStringUTFChars(input, nativeString);
        return count;
    }

    // 检查是否为回文
    JNIEXPORT jboolean JNICALL Java_com_example_demo_StringUtils_isPalindrome(JNIEnv *env, jclass clazz, jstring input) {
        const char* nativeString = env->GetStringUTFChars(input, 0);
        std::string str(nativeString);
        
        // 转换为小写并移除空格
        std::string cleaned;
        for (char c : str) {
            if (std::isalnum(c)) {
                cleaned += std::tolower(c);
            }
        }
        
        std::string reversed = cleaned;
        std::reverse(reversed.begin(), reversed.end());
        
        env->ReleaseStringUTFChars(input, nativeString);
        return cleaned == reversed ? JNI_TRUE : JNI_FALSE;
    }
}
