#include <jni.h>
#include <unistd.h>
#include <sys/utsname.h>
#include <sys/sysinfo.h>
#include <fstream>
#include <string>

extern "C" {
    // 获取系统架构信息
    JNIEXPORT jstring JNICALL Java_com_example_demo_SystemInfo_getArchitecture(JNIEnv *env, jclass clazz) {
        struct utsname buffer;
        if (uname(&buffer) != 0) {
            return env->NewStringUTF("unknown");
        }
        return env->NewStringUTF(buffer.machine);
    }

    // 获取系统内核版本
    JNIEXPORT jstring JNICALL Java_com_example_demo_SystemInfo_getKernelVersion(JNIEnv *env, jclass clazz) {
        struct utsname buffer;
        if (uname(&buffer) != 0) {
            return env->NewStringUTF("unknown");
        }
        return env->NewStringUTF(buffer.release);
    }

    // 获取CPU核心数
    JNIEXPORT jint JNICALL Java_com_example_demo_SystemInfo_getCpuCores(JNIEnv *env, jclass clazz) {
        return sysconf(_SC_NPROCESSORS_ONLN);
    }

    // 获取系统总内存（MB）
    JNIEXPORT jlong JNICALL Java_com_example_demo_SystemInfo_getTotalMemoryMB(JNIEnv *env, jclass clazz) {
        struct sysinfo info;
        if (sysinfo(&info) != 0) {
            return -1;
        }
        return (info.totalram * info.mem_unit) / (1024 * 1024);
    }

    // 获取系统可用内存（MB）
    JNIEXPORT jlong JNICALL Java_com_example_demo_SystemInfo_getAvailableMemoryMB(JNIEnv *env, jclass clazz) {
        struct sysinfo info;
        if (sysinfo(&info) != 0) {
            return -1;
        }
        return (info.freeram * info.mem_unit) / (1024 * 1024);
    }

    // 获取系统负载平均值
    JNIEXPORT jdouble JNICALL Java_com_example_demo_SystemInfo_getLoadAverage(JNIEnv *env, jclass clazz) {
        double loadavg[3];
        if (getloadavg(loadavg, 1) == -1) {
            return -1.0;
        }
        return loadavg[0];
    }
}
