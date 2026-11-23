FROM messense/rust-musl-cross:aarch64-musl

RUN apt-get update && apt-get install -y --no-install-recommends zstd \
    && rm -rf /var/lib/apt/lists/*
