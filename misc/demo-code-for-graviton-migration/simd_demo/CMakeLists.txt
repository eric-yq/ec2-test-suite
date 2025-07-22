cmake_minimum_required(VERSION 3.10)
project(SIMD_Demo)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_C_STANDARD 11)

# 检查编译器支持
include(CheckCXXCompilerFlag)

# 设置编译选项
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -O3")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wextra -O3")
    
    # SIMD指令集支持
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -msse -msse2 -msse3 -msse4.1 -msse4.2")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mavx -mavx2 -mfma")
    
    # 检查AVX512支持
    check_cxx_compiler_flag("-mavx512f" COMPILER_SUPPORTS_AVX512F)
    if(COMPILER_SUPPORTS_AVX512F)
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mavx512f -mavx512dq -mavx512bw -mavx512vl")
        add_definitions(-DAVX512_SUPPORTED)
    endif()
    
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /arch:AVX2")
    add_definitions(-DAVX512_SUPPORTED)
endif()

# 包含目录
include_directories(include)

# 源文件
set(SOURCES
    src/main.cpp
    src/vector_math.cpp
    src/image_processing.cpp
    src/matrix_operations.cpp
    src/audio_processing.cpp
    src/data_analytics.cpp
    src/simd_utils.cpp
)

# 创建可执行文件
add_executable(simd_demo ${SOURCES})

# 链接数学库
target_link_libraries(simd_demo m)
