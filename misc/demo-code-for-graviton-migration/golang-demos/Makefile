.PHONY: all build build-arm64 clean run-base64 run-reverser run-counter

# Binary names
BASE64_BIN = base64_tool
REVERSER_BIN = string_reverser
COUNTER_BIN = char_counter

# ARM64 binary suffixes
ARM64_SUFFIX = _arm64

# Default target
all: build

# Build all binaries for current architecture
build:
	go build -o $(BASE64_BIN) base64_encoder.go
	go build -o $(REVERSER_BIN) string_reverser.go
	go build -o $(COUNTER_BIN) char_counter.go

# Build all binaries specifically for ARM64 architecture
build-arm64:
	GOOS=linux GOARCH=arm64 go build -o $(BASE64_BIN)$(ARM64_SUFFIX) base64_encoder.go
	GOOS=linux GOARCH=arm64 go build -o $(REVERSER_BIN)$(ARM64_SUFFIX) string_reverser.go
	GOOS=linux GOARCH=arm64 go build -o $(COUNTER_BIN)$(ARM64_SUFFIX) char_counter.go

# Build for multiple architectures (current and ARM64)
build-all: build build-arm64

# Clean up binaries
clean:
	rm -f $(BASE64_BIN) $(REVERSER_BIN) $(COUNTER_BIN)
	rm -f $(BASE64_BIN)$(ARM64_SUFFIX) $(REVERSER_BIN)$(ARM64_SUFFIX) $(COUNTER_BIN)$(ARM64_SUFFIX)

# Run examples
run-base64:
	./$(BASE64_BIN) encode "Hello, World!"
	./$(BASE64_BIN) decode "SGVsbG8sIFdvcmxkIQ=="

run-reverser:
	./$(REVERSER_BIN) "Hello, World!"

run-counter:
	./$(COUNTER_BIN) "Hello, World!"

# Docker build
docker-build:
	docker build -t golang-demos:latest .

# Docker build for ARM64
docker-build-arm64:
	docker buildx build --platform linux/arm64 -t golang-demos:arm64 .
