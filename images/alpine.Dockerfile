FROM alpine:3.22

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
