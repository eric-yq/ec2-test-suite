cmake_minimum_required(VERSION 3.22)

project(chatbot-arm64)

set(LLAMA_CURL ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Detect ARM64 architecture
if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
    # 禁用 SVE — 必须在编译器层面关闭！
    # 原因：llama.cpp b3145 的 ggml.c 通过 __ARM_FEATURE_SVE 宏（而非 CMake 变量）
    #       决定是否编译 SVE 代码路径，且硬编码要求 svcntb()==32 (256-bit)
    # Graviton4 (Neoverse V2) SVE2 向量宽度仅 128-bit，会触发 GGML_ASSERT 失败
    #
    # 解决方案：使用 -mcpu=native+nosve 显式禁用 SVE 指令集
    # 这样 GCC 不会定义 __ARM_FEATURE_SVE，ggml.c 会走 NEON 路径
    # NEON 在 Graviton4 上是 4x128b 流水线，性能依然很好
    set(LLAMA_SVE OFF)

    # GCC 11 不支持 -mcpu=native+nosve 语法（需要 GCC 12+）
    # 改用 -march=armv8.4-a+dotprod+i8mm 显式指定架构特性，不包含 sve
    # 这样 __ARM_FEATURE_SVE 不会被定义，ggml.c 走 NEON 路径
    # 同时保留 dotprod 和 i8mm 加速量化推理
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -march=armv8.4-a+dotprod+i8mm -mtune=neoverse-v2")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=armv8.4-a+dotprod+i8mm -mtune=neoverse-v2")
endif()

add_subdirectory(llama.cpp)

add_library(chatbot-arm64 SHARED chatbot.cpp)
target_link_libraries(chatbot-arm64 PRIVATE llama common ${CMAKE_THREAD_LIBS_INIT})
target_compile_features(chatbot-arm64 PRIVATE cxx_std_11)
