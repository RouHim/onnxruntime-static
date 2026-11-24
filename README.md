<p align="center">
  <img src=".github/readme/banner.svg" alt="onnxruntime-static" width="600">
</p>

<p align="center">
  <a href="https://github.com/RouHim/onnxruntime-static/actions/workflows/build.yml"><img src="https://github.com/RouHim/onnxruntime-static/actions/workflows/build.yml/badge.svg?branch=main" alt="CI status"></a>
  <a href="https://github.com/RouHim/onnxruntime-static/releases/latest"><img src="https://img.shields.io/github/v/release/RouHim/onnxruntime-static" alt="Latest release"></a>
  <a href="https://github.com/RouHim/onnxruntime-static/releases/latest"><img src="https://img.shields.io/badge/arch-x86__64%20%7C%20aarch64-blue" alt="Supported architectures"></a>
</p>

<p align="center">
  Unofficial static CPU builds of ONNX Runtime for glibc and musl Linux, ready to link into C++ and Rust programs.
</p>

## Motivation

Static linking keeps the inference runtime inside the binary that ships. A program linked against a musl archive runs in an empty container or on a minimal distribution without a glibc runtime. Consumers pin one tarball and its SHA-256 instead of rebuilding ONNX Runtime themselves.

This project is not affiliated with or endorsed by Microsoft.

## How it works

Each release builds a tagged ONNX Runtime version from source in a Linux container. The build is CPU only: CUDA, TensorRT, OpenVINO and the other non-CPU execution providers are disabled. It produces a shared library, merges the internal static libraries into one `libonnxruntime.a`, and packages that archive with the public C and C++ headers.

Before publishing, CI unpacks the tarball again, links the smoke test against it with the consumer toolchain, and runs the binary against a small model. A release carries one tarball per target, `SHA256SUMS`, and a build provenance attestation.

## Features

- Prebuilt static archive for each target, so the consumer does not have to build ONNX Runtime.
- Full operator set, including contrib ops, with no minimal or reduced build.
- C and C++ headers shipped in the same archive.
- SHA-256 checksums and a build provenance attestation per release.
- Immutable release assets, so a pinned checksum stays valid.

## Run the library

### Prerequisites

Linux on x86_64 or aarch64, plus `curl`, `zstd`, `sha256sum`, and a C++17 toolchain. The musl targets need a musl C++ toolchain as well.

Download one target, verify the checksum, and extract it:

```sh
version=1.32.0; target=x86_64-unknown-linux-musl
base=https://github.com/RouHim/onnxruntime-static/releases/download/v$version
curl -fsSLO "$base/onnxruntime-$version-$target-static.tar.zst" -O "$base/SHA256SUMS" && sha256sum -c SHA256SUMS --ignore-missing && mkdir -p vendor/ort && tar --zstd -xf "onnxruntime-$version-$target-static.tar.zst" -C vendor/ort
```

`target` also accepts `x86_64-unknown-linux-gnu` and `aarch64-unknown-linux-musl`. The archive contains `lib/libonnxruntime.a`, the headers under `include/`, `LICENSE`, `ThirdPartyNotices.txt`, and `VERSION`, which records the ONNX Runtime version and upstream commit.

An application creates an environment, opens a model, and runs inference:

```cpp
#include <onnxruntime_cxx_api.h>

int main() {
  Ort::Env env(ORT_LOGGING_LEVEL_WARNING, "app");
  Ort::Session session(env, "model.onnx", Ort::SessionOptions{});
}
```

With a musl archive, link with the static flags:

```sh
g++ -std=c++17 -O2 -I vendor/ort/include app.cc -L vendor/ort/lib -lonnxruntime -static -static-libstdc++ -static-libgcc -lpthread -lm -o app
```

With the gnu archive, use `-lpthread -ldl -lm` instead of the static flags. [smoke/smoke.cc](smoke/smoke.cc) is a complete example that creates a tensor, runs inference, and checks the output.

Pin the release tag and its SHA-256 in the consumer repository. With `gh` installed, `gh attestation verify <tarball> --repo RouHim/onnxruntime-static` checks the build provenance.

## Limitations

- CPU execution only. GPU and the other non-CPU providers are disabled at build time.
- Linux on x86_64 and aarch64 only. There are no Windows or macOS archives.
- A musl consumer needs a GCC at least as new as the archive's build GCC. The `v1.32.0` musl archives use GCC 12.4 and current builds use GCC 14.2, so a GCC 12.4 consumer cannot link the newer archives (`std::__format`, `_M_replace_cold`).
- The archive is about 20 MB compressed.

## Troubleshooting

- `undefined reference to std::__format` or `_M_replace_cold`: the consumer toolchain is older than the archive. See [Limitations](#limitations).
- `sha256sum: WARNING: 1 computed checksum did NOT match`: delete the download and retry. Do not use an archive that fails the check.
- `tar: zstd: Cannot exec`: install `zstd`.
- No release for a version: the build did not publish. Check the latest workflow run and retry.

Report problems at [github.com/RouHim/onnxruntime-static/issues](https://github.com/RouHim/onnxruntime-static/issues).

## Resources

- [ONNX Runtime documentation](https://onnxruntime.ai/docs/)
- [C API reference](https://onnxruntime.ai/docs/api/c/)
