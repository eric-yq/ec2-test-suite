# Makefile for building native libraries (Multi-architecture support)

CC = gcc
CXX = g++
CFLAGS = -fPIC -O2 -Wall -Wextra -std=c99
CXXFLAGS = -fPIC -O2 -Wall -Wextra -std=c++11
LDFLAGS = -shared

# 检测当前架构
CURRENT_ARCH := $(shell uname -m)

# 架构映射
ifeq ($(CURRENT_ARCH),x86_64)
    NATIVE_ARCH = x86_64
    CROSS_ARCH = aarch64
    CROSS_CC = aarch64-linux-gnu-gcc
    CROSS_CXX = aarch64-linux-gnu-g++
else ifeq ($(CURRENT_ARCH),aarch64)
    NATIVE_ARCH = aarch64
    CROSS_ARCH = x86_64
    CROSS_CC = x86_64-linux-gnu-gcc
    CROSS_CXX = x86_64-linux-gnu-g++
else
    $(error Unsupported architecture: $(CURRENT_ARCH))
endif

# 目录
SRC_DIR = src
BUILD_DIR = build

# 源文件
MATH_SRC = $(SRC_DIR)/math_ops.c
STRING_SRC = $(SRC_DIR)/string_ops.c
SYSTEM_SRC = $(SRC_DIR)/system_ops.cpp

# 本地架构目标文件
MATH_LIB_NATIVE = $(BUILD_DIR)/libmath_ops_$(NATIVE_ARCH).so
STRING_LIB_NATIVE = $(BUILD_DIR)/libstring_ops_$(NATIVE_ARCH).so
SYSTEM_LIB_NATIVE = $(BUILD_DIR)/libsystem_ops_$(NATIVE_ARCH).so

# 交叉编译目标文件
MATH_LIB_CROSS = $(BUILD_DIR)/libmath_ops_$(CROSS_ARCH).so
STRING_LIB_CROSS = $(BUILD_DIR)/libstring_ops_$(CROSS_ARCH).so
SYSTEM_LIB_CROSS = $(BUILD_DIR)/libsystem_ops_$(CROSS_ARCH).so

# 默认目标（仅本地架构）
all: $(BUILD_DIR) $(MATH_LIB_NATIVE) $(STRING_LIB_NATIVE) $(SYSTEM_LIB_NATIVE)

# 多架构目标（本地 + 交叉编译）
multiarch: $(BUILD_DIR) native cross

# 本地架构编译
native: $(MATH_LIB_NATIVE) $(STRING_LIB_NATIVE) $(SYSTEM_LIB_NATIVE)

# 交叉编译
cross: $(MATH_LIB_CROSS) $(STRING_LIB_CROSS) $(SYSTEM_LIB_CROSS)

# 创建构建目录
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# 本地架构编译规则
$(MATH_LIB_NATIVE): $(MATH_SRC)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<
	@echo "Built math operations library ($(NATIVE_ARCH)): $@"

$(STRING_LIB_NATIVE): $(STRING_SRC)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<
	@echo "Built string operations library ($(NATIVE_ARCH)): $@"

$(SYSTEM_LIB_NATIVE): $(SYSTEM_SRC)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ $<
	@echo "Built system operations library ($(NATIVE_ARCH)): $@"

# 交叉编译规则
$(MATH_LIB_CROSS): $(MATH_SRC)
	@if command -v $(CROSS_CC) >/dev/null 2>&1; then \
		$(CROSS_CC) $(CFLAGS) $(LDFLAGS) -o $@ $<; \
		echo "Built math operations library ($(CROSS_ARCH)): $@"; \
	else \
		echo "Warning: Cross compiler $(CROSS_CC) not found, skipping $(CROSS_ARCH) build"; \
		echo "To install cross compiler on Ubuntu/Debian:"; \
		if [ "$(CROSS_ARCH)" = "aarch64" ]; then \
			echo "  sudo apt-get install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu"; \
		else \
			echo "  sudo apt-get install gcc-x86-64-linux-gnu g++-x86-64-linux-gnu"; \
		fi; \
	fi

$(STRING_LIB_CROSS): $(STRING_SRC)
	@if command -v $(CROSS_CC) >/dev/null 2>&1; then \
		$(CROSS_CC) $(CFLAGS) $(LDFLAGS) -o $@ $<; \
		echo "Built string operations library ($(CROSS_ARCH)): $@"; \
	else \
		echo "Warning: Cross compiler $(CROSS_CC) not found, skipping $(CROSS_ARCH) build"; \
	fi

$(SYSTEM_LIB_CROSS): $(SYSTEM_SRC)
	@if command -v $(CROSS_CXX) >/dev/null 2>&1; then \
		$(CROSS_CXX) $(CXXFLAGS) $(LDFLAGS) -o $@ $<; \
		echo "Built system operations library ($(CROSS_ARCH)): $@"; \
	else \
		echo "Warning: Cross compiler $(CROSS_CXX) not found, skipping $(CROSS_ARCH) build"; \
	fi

# 清理
clean:
	rm -rf $(BUILD_DIR)
	@echo "Cleaned build directory"

# 显示架构信息
info:
	@echo "Current Architecture: $(CURRENT_ARCH)"
	@echo "Native Architecture: $(NATIVE_ARCH)"
	@echo "Cross Architecture: $(CROSS_ARCH)"
	@echo "Native Compiler: $(CC) $(CXX)"
	@echo "Cross Compiler: $(CROSS_CC) $(CROSS_CXX)"
	@echo "Build Directory: $(BUILD_DIR)"

# 检查交叉编译工具
check-cross:
	@echo "Checking cross compilation tools..."
	@if command -v $(CROSS_CC) >/dev/null 2>&1; then \
		echo "✓ $(CROSS_CC) found"; \
	else \
		echo "✗ $(CROSS_CC) not found"; \
	fi
	@if command -v $(CROSS_CXX) >/dev/null 2>&1; then \
		echo "✓ $(CROSS_CXX) found"; \
	else \
		echo "✗ $(CROSS_CXX) not found"; \
	fi

# 安装交叉编译工具
install-cross-tools:
	@echo "Installing cross compilation tools..."
	@if [ "$(CROSS_ARCH)" = "aarch64" ]; then \
		echo "Installing ARM64 cross compiler..."; \
		sudo apt-get update && sudo apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu; \
	elif [ "$(CROSS_ARCH)" = "x86_64" ]; then \
		echo "Installing x86_64 cross compiler..."; \
		sudo apt-get update && sudo apt-get install -y gcc-x86-64-linux-gnu g++-x86-64-linux-gnu; \
	fi

# 安装到 Java resources
install: multiarch
	cp $(BUILD_DIR)/*.so ../src/main/resources/native/
	@echo "Installed native libraries to Java resources"

.PHONY: all multiarch native cross clean info check-cross install-cross-tools install
