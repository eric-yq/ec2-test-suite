CC = gcc
CFLAGS = -Wall -O3 -march=native -mavx -mavx2 -mfma -msse4.2
LDFLAGS = -lm

# Check if AVX-512 is supported by the compiler
ifeq ($(shell $(CC) -mavx512f -E -xc /dev/null > /dev/null 2>&1 && echo yes || echo no),yes)
    CFLAGS += -mavx512f -mavx512dq -mavx512bw -mavx512vl
endif

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

# Show CPU info
cpu-info:
	@echo "CPU Information:"
	@lscpu | grep -E 'Model name|Flags' || echo "lscpu not available"
	@echo ""
	@echo "SIMD Support:"
	@grep -q "sse" /proc/cpuinfo && echo "SSE: Supported" || echo "SSE: Not supported"
	@grep -q "avx" /proc/cpuinfo && echo "AVX: Supported" || echo "AVX: Not supported"
	@grep -q "avx2" /proc/cpuinfo && echo "AVX2: Supported" || echo "AVX2: Not supported"
	@grep -q "avx512" /proc/cpuinfo && echo "AVX-512: Supported" || echo "AVX-512: Not supported"
