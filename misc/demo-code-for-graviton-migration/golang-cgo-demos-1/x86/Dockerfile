FROM golang:1.21-bullseye

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    g++ \
    libc6-dev \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

# Copy the source code
COPY . .

# Build the shared library and Go application
RUN cd /app && make build

# Set the library path for runtime
ENV LD_LIBRARY_PATH=/app/lib

# Run the application
CMD ["/app/cgo-demo"]
