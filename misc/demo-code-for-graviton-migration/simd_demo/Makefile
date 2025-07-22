# SIMD演示程序 Makefile
# 备选构建方案，如果没有CMake可以使用此Makefile

CXX = g++
CC = gcc

# 编译选项
CXXFLAGS = -std=c++17 -Wall -Wextra -O3
CFLAGS = -std=c11 -Wall -Wextra -O3

# SIMD指令集支持
SIMD_FLAGS = -msse -msse2 -msse3 -msse4.1 -msse4.2 -mavx -mavx2

# 检查AVX512支持
AVX512_SUPPORT := $(shell $(CXX) -mavx512f -E -x c++ /dev/null > /dev/null 2>&1 && echo "yes" || echo "no")
ifeq ($(AVX512_SUPPORT),yes)
    SIMD_FLAGS += -mavx512f -mavx512dq -mavx512bw -mavx512vl
    CXXFLAGS += -DAVX512_SUPPORTED
endif

# 最终编译选项
CXXFLAGS += $(SIMD_FLAGS)
CFLAGS += $(SIMD_FLAGS)

# 目录
SRCDIR = src
INCDIR = include
OBJDIR = obj
BINDIR = bin

# 源文件
SOURCES = $(wildcard $(SRCDIR)/*.cpp)
OBJECTS = $(SOURCES:$(SRCDIR)/%.cpp=$(OBJDIR)/%.o)

# 目标程序
TARGET = $(BINDIR)/simd_demo

# 默认目标
all: $(TARGET)

# 创建目录
$(OBJDIR):
	mkdir -p $(OBJDIR)

$(BINDIR):
	mkdir -p $(BINDIR)

# 编译目标文件
$(OBJDIR)/%.o: $(SRCDIR)/%.cpp | $(OBJDIR)
	$(CXX) $(CXXFLAGS) -I$(INCDIR) -c $< -o $@

# 链接可执行文件
$(TARGET): $(OBJECTS) | $(BINDIR)
	$(CXX) $(OBJECTS) -o $@ -lm

# 清理
clean:
	rm -rf $(OBJDIR) $(BINDIR)

# 重新构建
rebuild: clean all

# 运行程序
run: $(TARGET)
	./$(TARGET)

# 显示编译信息
info:
	@echo "编译器: $(CXX)"
	@echo "C++标准: C++17"
	@echo "优化级别: -O3"
	@echo "SIMD支持: $(SIMD_FLAGS)"
	@echo "AVX512支持: $(AVX512_SUPPORT)"
	@echo "源文件: $(SOURCES)"
	@echo "目标文件: $(OBJECTS)"
	@echo "可执行文件: $(TARGET)"

# 安装依赖 (Ubuntu/Debian)
install-deps:
	sudo apt-get update
	sudo apt-get install -y build-essential cmake

# 检查CPU特性
check-cpu:
	@echo "检查CPU SIMD支持:"
	@grep -o 'sse\|sse2\|sse3\|ssse3\|sse4_1\|sse4_2\|avx\|avx2\|avx512' /proc/cpuinfo | sort | uniq || echo "无法检测CPU特性"

.PHONY: all clean rebuild run info install-deps check-cpu
