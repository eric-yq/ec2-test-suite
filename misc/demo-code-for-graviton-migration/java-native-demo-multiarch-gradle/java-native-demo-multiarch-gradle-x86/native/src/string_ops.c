/**
 * String Operations Native Library
 * 提供字符串处理功能 (x86_64 only)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * 计算字符串长度
 */
int string_length(const char* str) {
    if (str == NULL) {
        return -1;
    }
    return (int)strlen(str);
}

/**
 * 反转字符串
 * 注意：返回的字符串需要调用者负责释放内存
 */
char* reverse_string(const char* str) {
    if (str == NULL) {
        return NULL;
    }
    
    int len = strlen(str);
    char* reversed = (char*)malloc((len + 1) * sizeof(char));
    
    if (reversed == NULL) {
        return NULL;
    }
    
    for (int i = 0; i < len; i++) {
        reversed[i] = str[len - 1 - i];
    }
    reversed[len] = '\0';
    
    return reversed;
}

/**
 * 转换为大写
 * 注意：返回的字符串需要调用者负责释放内存
 */
char* to_uppercase(const char* str) {
    if (str == NULL) {
        return NULL;
    }
    
    int len = strlen(str);
    char* uppercase = (char*)malloc((len + 1) * sizeof(char));
    
    if (uppercase == NULL) {
        return NULL;
    }
    
    for (int i = 0; i < len; i++) {
        uppercase[i] = toupper(str[i]);
    }
    uppercase[len] = '\0';
    
    return uppercase;
}

/**
 * 释放由本库分配的字符串内存
 */
void free_string(char* str) {
    if (str != NULL) {
        free(str);
    }
}

#ifdef __cplusplus
}
#endif
