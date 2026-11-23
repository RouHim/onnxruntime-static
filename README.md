# onnxruntime-static

Unofficial, CPU-only static builds of [ONNX Runtime](https://onnxruntime.ai) for musl and glibc Linux binaries.

Not affiliated with or endorsed by Microsoft. The project builds ONNX Runtime from a tagged upstream source, runs an inference smoke test, and publishes a static archive for each target. Consumers pin a release and its SHA-256; Renovate can update both.

Releases cover `x86_64-unknown-linux-gnu` for host tooling, plus `x86_64-unknown-linux-musl` and `aarch64-unknown-linux-musl` for fully static binaries. Build, release, and verification details are in [DEVELOPMENT.md](DEVELOPMENT.md).

## Requirements

- Linux on x86_64 or aarch64.
- A C++17 compiler, `tar` with zstd support, and `sha256sum`.
- For musl targets, a musl toolchain from the same GCC generation as the archive. The `v1.32.0` musl archives use GCC 12.4; current builds use Alpine 3.22 GCC 14.2. A GCC 14.2 archive does not link with a GCC 12.4 consumer (`std::__format`, `_M_replace_cold`).

## Install

Download one target, verify the checksum, and extract it:

```sh
version=1.32.0; target=x86_64-unknown-linux-musl
base=https://github.com/RouHim/onnxruntime-static/releases/download/v$version
curl -fLO "$base/onnxruntime-$version-$target-static.tar.zst" "$base/SHA256SUMS" && sha256sum -c SHA256SUMS --ignore-missing && mkdir -p vendor/ort && tar --zstd -xf "onnxruntime-$version-$target-static.tar.zst" -C vendor/ort
```

The archive has `lib/libonnxruntime.a`, headers under `include/`, `LICENSE`, `ThirdPartyNotices.txt`, and `VERSION`. Releases are immutable: assets are never replaced. Rebuilding the same ONNX Runtime version requires a new version tag or a coordinated pin change; replacing an asset would invalidate SHA-256 pins.

## Usage

```cpp
#include <onnxruntime_cxx_api.h>

int main() {
  Ort::Env env(ORT_LOGGING_LEVEL_WARNING, "app");
  Ort::Session session(env, "model.onnx", Ort::SessionOptions{});
}
```

Compile and link:

```sh
g++ -std=c++17 -O2 -I vendor/ort/include app.cc -L vendor/ort/lib -lonnxruntime -lpthread -ldl -lm -o app
./app
```

For musl, use `-static -static-libstdc++ -static-libgcc -lpthread -lm` in place of `-lpthread -ldl -lm`. [smoke/smoke.cc](smoke/smoke.cc) is a complete example that creates a tensor, runs inference, and checks the output.

## Troubleshooting and help

- `undefined reference to std::__format` or `_M_replace_cold`: the consumer GCC is older than the archive's build GCC. Link with the archive's build toolchain, or a newer one.
- `sha256sum: WARNING: 1 computed checksum did NOT match`: remove the download and retry. Do not use an archive that fails the check.
- `tar: zstd: Cannot exec`: install `zstd`.
- A missing release means the build failed before publishing. Check the Actions run and retry.

Report problems at [github.com/RouHim/onnxruntime-static/issues](https://github.com/RouHim/onnxruntime-static/issues).

## License

The build scripts and CI configuration are MIT licensed; see [LICENSE](LICENSE). ONNX Runtime is MIT licensed, and each archive includes its `LICENSE` and `ThirdPartyNotices.txt`.

The musl recipe, including the shared-library build, the `ar -M` merge, and the FlatBuffers `strtoull_l` workaround, came from [RapidAI/OnnxruntimeBuilder](https://github.com/RapidAI/OnnxruntimeBuilder) (Apache-2.0).
