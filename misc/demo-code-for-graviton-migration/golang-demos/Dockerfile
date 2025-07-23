# Build stage
FROM --platform=${BUILDPLATFORM:-linux/amd64} golang:1.21-alpine AS builder

WORKDIR /app

# Copy source code
COPY *.go .
COPY Makefile .

# Build the applications
# The Dockerfile will use the architecture of the build platform
ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN echo "Building on $BUILDPLATFORM for $TARGETPLATFORM" && \
    go mod init golang-demos && \
    if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        make build-arm64 && \
        mv *_arm64 /tmp/ && \
        mv /tmp/base64_tool_arm64 /app/base64_tool && \
        mv /tmp/string_reverser_arm64 /app/string_reverser && \
        mv /tmp/char_counter_arm64 /app/char_counter; \
    else \
        make build; \
    fi

# Final stage
FROM --platform=${TARGETPLATFORM:-linux/amd64} alpine:latest

WORKDIR /app

# Copy binaries from builder stage
COPY --from=builder /app/base64_tool /app/
COPY --from=builder /app/string_reverser /app/
COPY --from=builder /app/char_counter /app/

# Set executable permissions
RUN chmod +x /app/base64_tool /app/string_reverser /app/char_counter

# Create a simple entrypoint script
RUN echo '#!/bin/sh' > /app/entrypoint.sh && \
    echo 'echo "Available tools:"' >> /app/entrypoint.sh && \
    echo 'echo "1. Base64 Tool: /app/base64_tool [encode|decode] <string>"' >> /app/entrypoint.sh && \
    echo 'echo "2. String Reverser: /app/string_reverser <string>"' >> /app/entrypoint.sh && \
    echo 'echo "3. Character Counter: /app/char_counter <string>"' >> /app/entrypoint.sh && \
    echo 'echo ""' >> /app/entrypoint.sh && \
    echo 'exec "$@"' >> /app/entrypoint.sh && \
    chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/bin/sh"]
