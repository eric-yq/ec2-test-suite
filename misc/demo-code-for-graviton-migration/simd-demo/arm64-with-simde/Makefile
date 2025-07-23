CC = gcc
# 在 x86 环境中编译，但代码将兼容 ARM64
CFLAGS = -Wall -O3 -DSIMDE_ENABLE_NATIVE_ALIASES
LDFLAGS = -lm

SRC_DIR = src
BUILD_DIR = build
INCLUDE_DIR = include

SRCS = $(wildcard $(SRC_DIR)/*.c)
OBJS = $(patsubst $(SRC_DIR)/%.c,$(BUILD_DIR)/%.o,$(SRCS))
TARGET = $(BUILD_DIR)/simd_demo

.PHONY: all clean run

all: $(TARGET)

$(TARGET): $(OBJS)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)
	@echo "Build successful! Run with './$(TARGET)'"

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -I$(INCLUDE_DIR) -c -o $@ $<

run: $(TARGET)
	./$(TARGET)

clean:
	rm -rf $(BUILD_DIR)

# 在 ARM64 环境中，应使用以下标志
arm64:
	$(MAKE) CFLAGS="-Wall -O3 -march=armv8-a+simd -DSIMDE_ENABLE_NATIVE_ALIASES"

# Show CPU info
cpu-info:
	@echo "CPU Information:"
	@lscpu | grep -E 'Model name|Flags' || echo "lscpu not available"
	@echo ""
	@echo "SIMD Support:"
	@echo "ARM NEON: $(shell grep -q 'neon\|asimd' /proc/cpuinfo && echo 'Supported' || echo 'Not supported')"
	@echo "SVE: $(shell grep -q 'sve' /proc/cpuinfo && echo 'Supported' || echo 'Not supported')"
	@echo "x86 SSE: $(shell grep -q 'sse' /proc/cpuinfo && echo 'Supported' || echo 'Not supported')"
	@echo "x86 AVX: $(shell grep -q 'avx' /proc/cpuinfo && echo 'Supported' || echo 'Not supported')"
