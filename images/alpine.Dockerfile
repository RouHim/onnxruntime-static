FROM alpine:3.22@sha256:49340b346798875b5592e5d420241f2f9cfba5f47e62ebb1446a1b34734e898f

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
