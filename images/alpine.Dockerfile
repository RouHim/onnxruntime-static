FROM alpine:3.24@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf

# Native musl toolchain. CC/CXX make CMake pick the Alpine GCC 14.2 compilers;
# TARGET_CXX satisfies the build script's musl guard and the link preflight.
ENV CC=gcc \
    CXX=g++ \
    TARGET_CXX=g++

RUN apk add --no-cache \
    bash \
    binutils \
    build-base \
    ca-certificates \
    cmake \
    curl \
    file \
    findutils \
    git \
    libstdc++-dev \
    linux-headers \
    make \
    patch \
    perl \
    pkgconf \
    py3-flatbuffers \
    py3-numpy \
    py3-packaging \
    py3-protobuf \
    python3 \
    tar \
    xz \
    zlib-dev \
    zstd

WORKDIR /src
