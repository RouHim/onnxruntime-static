FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    file \
    git \
    make \
    patch \
    pkg-config \
    python3 \
    python3-flatbuffers \
    python3-numpy \
    python3-packaging \
    python3-protobuf \
    tar \
    xz-utils \
    zlib1g-dev \
    zstd \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
