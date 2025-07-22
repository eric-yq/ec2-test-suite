.PHONY: all clean build run

# Default target
all: build

# Build the shared library first
lib/libstringops.so: src/string_ops.c src/string_ops.h
	mkdir -p lib
	gcc -shared -fPIC -o lib/libstringops.so src/string_ops.c

# Copy the header to the lib directory for easier access
lib/string_ops.h: src/string_ops.h
	mkdir -p lib
	cp src/string_ops.h lib/

# Build the Go application
build: lib/libstringops.so lib/string_ops.h
	cd src && CGO_ENABLED=1 go build -o ../cgo-demo .

# Run the application
run: build
	./cgo-demo

# Clean up
clean:
	rm -f cgo-demo
	rm -f lib/libstringops.so
	rm -f lib/string_ops.h
