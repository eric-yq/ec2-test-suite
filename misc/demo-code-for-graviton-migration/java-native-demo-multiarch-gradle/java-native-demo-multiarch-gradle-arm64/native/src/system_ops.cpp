/**
 * System Operations Native Library
 * 提供系统信息获取功能 (x86_64 only)
 */

#include <chrono>
#include <string>
#include <sstream>
#include <unistd.h>
#include <sys/utsname.h>
#include <cstring>
#include <cstdlib>

extern "C" {

/**
 * 获取当前时间戳（毫秒）
 */
long long get_current_timestamp() {
    auto now = std::chrono::system_clock::now();
    auto duration = now.time_since_epoch();
    auto millis = std::chrono::duration_cast<std::chrono::milliseconds>(duration).count();
    return millis;
}

/**
 * 获取当前进程 ID
 */
int get_process_id() {
    return getpid();
}

/**
 * 获取系统信息
 * 注意：返回的字符串需要调用者负责释放内存
 */
char* get_system_info() {
    struct utsname sys_info;
    
    if (uname(&sys_info) != 0) {
        return nullptr;
    }
    
    // 构建系统信息字符串
    std::ostringstream oss;
    oss << "System: " << sys_info.sysname
        << ", Node: " << sys_info.nodename
        << ", Release: " << sys_info.release
        << ", Version: " << sys_info.version
        << ", Machine: " << sys_info.machine;
    
    std::string info_str = oss.str();
    
    // 分配内存并复制字符串
    char* result = (char*)malloc((info_str.length() + 1) * sizeof(char));
    if (result != nullptr) {
        strcpy(result, info_str.c_str());
    }
    
    return result;
}

/**
 * 获取 CPU 核心数
 */
int get_cpu_cores() {
    return sysconf(_SC_NPROCESSORS_ONLN);
}

/**
 * 检查是否为 x86_64 架构
 */
int is_x86_64() {
    struct utsname sys_info;
    if (uname(&sys_info) != 0) {
        return 0;
    }
    
    return (strcmp(sys_info.machine, "x86_64") == 0) ? 1 : 0;
}

/**
 * 释放由本库分配的字符串内存
 */
void free_system_string(char* str) {
    if (str != nullptr) {
        free(str);
    }
}

} // extern "C"
