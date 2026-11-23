FROM messense/rust-musl-cross:aarch64-musl

RUN apt-get update && apt-get install -y --no-install-recommends \
    patch \
    python3-numpy \
    python3-packaging \
    zstd \
    && rm -rf /var/lib/apt/lists/*

# ONNX Runtime 1.32 requires CMake >= 3.28; Ubuntu 22.04 ships 3.22.
RUN python3 -m pip install --no-cache-dir cmake==3.28.4

WORKDIR /src
