# Stage 1: Build llama.cpp
FROM ubuntu:22.04 AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libcurl4-openssl-dev \
    pkg-config \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Build llama.cpp
WORKDIR /tmp/build

# Download and extract llama.cpp (more reliable than git clone)
RUN wget -O llama-cpp.tar.gz https://github.com/ggerganov/llama.cpp/archive/refs/heads/master.tar.gz && \
    tar -xzf llama-cpp.tar.gz && \
    mv llama.cpp-master llama.cpp

WORKDIR /tmp/build/llama.cpp

# Build with CMake
RUN cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_BLAS=OFF \
    -DGGML_CUBLAS=OFF \
    -DGGML_METAL=OFF \
    -DGGML_HIPBLAS=OFF \
    -DGGML_ACCELERATE=OFF \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF \
    -DLLAMA_BUILD_SERVER=ON \
    && cmake --build build --config Release --target llama-server -j$(nproc)

# Stage 2: Runtime image
FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    python3 \
    python3-pip \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages for metrics
RUN pip3 install prometheus-client requests psutil

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash llama

# Create directories with proper ownership
RUN mkdir -p /models /app/metrics /etc/supervisor/conf.d && \
    chown -R llama:llama /models /app

# Copy built binary from builder stage
COPY --from=builder /tmp/build/llama.cpp/build/bin/llama-server /usr/local/bin/llama-server
RUN chmod +x /usr/local/bin/llama-server

# Copy shared libraries if they exist - fixed approach
RUN mkdir -p /usr/local/lib
# Modified to use a safer approach
RUN bash -c 'if [ -d /tmp/build/llama.cpp/build/bin/ ] && [ "$(ls -A /tmp/build/llama.cpp/build/bin/*.so 2>/dev/null)" ]; then \
      cp /tmp/build/llama.cpp/build/bin/*.so /usr/local/lib/ 2>/dev/null || true; \
    fi && \
    if [ -d /tmp/build/llama.cpp/build/lib/ ] && [ "$(ls -A /tmp/build/llama.cpp/build/lib/*.so 2>/dev/null)" ]; then \
      cp /tmp/build/llama.cpp/build/lib/*.so /usr/local/lib/ 2>/dev/null || true; \
    fi'
RUN ldconfig

# Copy metrics exporter script and supervisor config
COPY metrics/exporter.py /app/metrics/exporter.py
COPY configs/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN chmod +x /app/metrics/exporter.py

# Expose ports
EXPOSE 8084 9090

# Health check for both services
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8084/health && curl -f http://localhost:9090/metrics || exit 1

# Use supervisor to run both services
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]