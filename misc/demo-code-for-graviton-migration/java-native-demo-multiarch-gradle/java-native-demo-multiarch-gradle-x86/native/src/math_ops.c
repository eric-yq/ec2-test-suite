/**
 * Math Operations Native Library
 * 提供基本数学运算功能 (x86_64 only)
 */

#include <math.h>

// 导出函数声明
#ifdef __cplusplus
extern "C" {
#endif

/**
 * 加法运算
 */
int add(int a, int b) {
    return a + b;
}

/**
 * 乘法运算
 */
int multiply(int a, int b) {
    return a * b;
}

/**
 * 平方根运算
 */
double sqrt_custom(double x) {
    if (x < 0) {
        return -1.0; // 错误值
    }
    return sqrt(x);
}

// 为了兼容 JNA 调用，提供别名
double sqrt(double x) __attribute__((alias("sqrt_custom")));

#ifdef __cplusplus
}
#endif
