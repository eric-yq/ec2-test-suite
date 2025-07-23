# Golang Demos

This project contains three simple Golang utilities:

1. **Base64 Encoder/Decoder**: Encode or decode strings using Base64
2. **String Reverser**: Reverse any input string
3. **Character Counter**: Count the frequency of each character in a string

## Building the Project

To build all utilities for your current architecture:

```bash
make build
```

To build specifically for ARM64 architecture:

```bash
make build-arm64
```

To build for both your current architecture and ARM64:

```bash
make build-all
```

This will create executable binaries:
- For current architecture: `base64_tool`, `string_reverser`, `char_counter`
- For ARM64: `base64_tool_arm64`, `string_reverser_arm64`, `char_counter_arm64`

## Usage Examples

### Base64 Encoder/Decoder

```bash
# Encode a string
./base64_tool encode "Hello, World!"

# Decode a Base64 string
./base64_tool decode "SGVsbG8sIFdvcmxkIQ=="
```

### String Reverser

```bash
./string_reverser "Hello, World!"
```

### Character Counter

```bash
./char_counter "Hello, World!"
```

## Running with Make

The Makefile includes convenience targets for running examples:

```bash
make run-base64
make run-reverser
make run-counter
```

## Docker Support

Build the Docker image for your current architecture:

```bash
make docker-build
```

Build the Docker image specifically for ARM64:

```bash
make docker-build-arm64
```

Run the container:

```bash
docker run -it golang-demos:latest
```

For ARM64 container:

```bash
docker run -it golang-demos:arm64
```

Inside the container, you can use any of the three tools.
