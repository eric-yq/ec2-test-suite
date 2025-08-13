# Makefile for building native libraries (x86_64 only)

CC = gcc
CXX = g++
CFLAGS = -fPIC -O2 -Wall -Wextra -std=c99
CXXFLAGS = -fPIC -O2 -Wall -Wextra -std=c++11
LDFLAGS = -shared

# 目标架构检查 - 仅支持 x86_64
ARCH := $(shell uname -m)
ifneq ($(ARCH),x86_64)
    $(error This build only supports x86_64 architecture, current: $(ARCH))
endif

# 目录
SRC_DIR = src
BUILD_DIR = build

# 源文件
MATH_SRC = $(SRC_DIR)/math_ops.c
STRING_SRC = $(SRC_DIR)/string_ops.c
SYSTEM_SRC = $(SRC_DIR)/system_ops.cpp

# 目标文件
MATH_LIB = $(BUILD_DIR)/libmath_ops.so
STRING_LIB = $(BUILD_DIR)/libstring_ops.so
SYSTEM_LIB = $(BUILD_DIR)/libsystem_ops.so

# 默认目标
all: $(BUILD_DIR) $(MATH_LIB) $(STRING_LIB) $(SYSTEM_LIB)

# 创建构建目录
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# 编译数学运算库
$(MATH_LIB): $(MATH_SRC)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<
	@echo "Built math operations library: $@"

# 编译字符串操作库
$(STRING_LIB): $(STRING_SRC)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<
	@echo "Built string operations library: $@"

# 编译系统信息库
$(SYSTEM_LIB): $(SYSTEM_SRC)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ $<
	@echo "Built system operations library: $@"

# 清理
clean:
	rm -rf $(BUILD_DIR)
	@echo "Cleaned build directory"

# 显示架构信息
info:
	@echo "Target Architecture: $(ARCH)"
	@echo "Compiler: $(CC) $(CXX)"
	@echo "Build Directory: $(BUILD_DIR)"

# 安装到 Java resources
install: all
	cp $(BUILD_DIR)/*.so ../src/main/resources/native/
	@echo "Installed native libraries to Java resources"

.PHONY: all clean info install
