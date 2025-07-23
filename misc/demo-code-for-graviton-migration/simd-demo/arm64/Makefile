CC = gcc
CFLAGS = -Wall -O3 -march=armv8-a -mtune=generic

# NEON is mandatory in ARMv8, no need for special flags

# Check if SVE is supported by the compiler
ifeq ($(shell $(CC) -march=armv8-a+sve -E -xc /dev/null > /dev/null 2>&1 && echo yes || echo no),yes)
    CFLAGS += -march=armv8-a+sve
endif

# Check if SVE2 is supported by the compiler
ifeq ($(shell $(CC) -march=armv8-a+sve2 -E -xc /dev/null > /dev/null 2>&1 && echo yes || echo no),yes)
    CFLAGS += -march=armv8-a+sve2
endif

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

# Show CPU info
cpu-info:
	@echo "CPU Information:"
	@lscpu || echo "lscpu not available"
	@echo ""
	@echo "SIMD Support:"
	@echo "NEON: Supported (mandatory in ARMv8)"
	@if grep -q "sve" /proc/cpuinfo 2>/dev/null; then echo "SVE: Supported"; else echo "SVE: Not supported"; fi
	@if grep -q "sve2" /proc/cpuinfo 2>/dev/null; then echo "SVE2: Supported"; else echo "SVE2: Not supported"; fi
