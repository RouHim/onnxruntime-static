# onnxruntime-static

Unofficial, CPU-only static builds of [ONNX Runtime](https://onnxruntime.ai)
for fully static musl binaries. Not affiliated with or endorsed by Microsoft.

The repository is an artifact factory: it builds ONNX Runtime from the upstream
tag, runs a real inference smoke test, and publishes the static archive. The
consumer pins a release version and SHA-256; Renovate can update both.

## Targets

| Target | Use |
| --- | --- |
| `x86_64-unknown-linux-gnu` | Host tests and tooling (glibc) |
| `x86_64-unknown-linux-musl` | Fully static x86_64 binaries |
| `aarch64-unknown-linux-musl` | Fully static aarch64 binaries |

Each release `v<version>` contains one tarball per target:

```
onnxruntime-1.32.0-x86_64-unknown-linux-musl-static.tar.zst
onnxruntime-1.32.0-aarch64-unknown-linux-musl-static.tar.zst
onnxruntime-1.32.0-x86_64-unknown-linux-gnu-static.tar.zst
SHA256SUMS
```

The tarball layout matches the archives previously used by turbo-pix:

```
lib/libonnxruntime.a
include/onnxruntime_cxx_api.h
include/onnxruntime_c_api.h
include/core/...
LICENSE
ThirdPartyNotices.txt
VERSION
```

`SHA256SUMS` intentionally stays below 5 KB: Renovate's
`github-release-attachments` datasource only parses small checksum assets.

## Consuming a build

```sh
version=1.32.0
target=x86_64-unknown-linux-musl
asset=onnxruntime-${version}-${target}-static.tar.zst
base_url="https://github.com/RouHim/onnxruntime-static/releases/download/v${version}"
curl -fL -o "$asset" "$base_url/$asset"
curl -fL -o SHA256SUMS "$base_url/SHA256SUMS"
sha256sum -c SHA256SUMS --ignore-missing
mkdir -p vendor/ort
tar --zstd -xf "$asset" -C vendor/ort
export ORT_LIB_PATH="$PWD/vendor/ort/lib"
```

Renovate can track the release and the asset digest. Use one pin file per
target (each asset has its own digest), pinning the **release tag** as
`currentValue` — the datasource looks up `/releases/tags/<currentValue>`:

```sh
# scripts/ort/x86_64-unknown-linux-musl.env
ORT_TAG=v1.32.0
ORT_SHA=8fa66a3e9e70f702baad7741968cb917e88f14f914c4247040ff2d4ba63c9c02
```

```json
{
  "customManagers": [
    {
      "customType": "regex",
      "managerFilePatterns": ["/(^|/)scripts/ort/x86_64-unknown-linux-musl\\.env$/"],
      "matchStrings": [
        "ORT_TAG=(?<currentValue>v\\d+\\.\\d+\\.\\d+)\\nORT_SHA=(?<currentDigest>[a-f0-9]{64})"
      ],
      "depNameTemplate": "RouHim/onnxruntime-static",
      "datasourceTemplate": "github-release-attachments",
      "versioningTemplate": "semver-coerced"
    }
  ]
}
```

Repeat the manager for the other target files.

Asset filenames embed the version on purpose: Renovate maps a known digest to a
filename in `SHA256SUMS`, then replaces the old version with the new one to find
the next release's asset.

## Toolchain

The musl artifacts are built with Alpine 3.22's GCC 14.2, matching turbo-pix's
Alpine release/container toolchain. The `v1.32.0` artifacts were built before
this switch with GCC 12.4; they still link under the Alpine consumer. A GCC
14.2 archive cannot be consumed by a GCC 12.4 link stage (`std::__format`
internals, `_M_replace_cold`), so keep the builder and consumer aligned.

Two patches are applied during the build: the FlatBuffers musl locale fix and
disabling ONNX Runtime's warnings-as-errors (GCC trips a false-positive
`-Werror=array-bounds`, first seen on GCC 12.4). Both live in `patches/`.

## Automation

The build script clones ONNX Runtime from `ORT_GIT_URL`, defaulting to the
GitCode sync (`https://gitcode.com/GitHub_Trending/on/onnxruntime.git`). The
upstream GitHub repository was removed, so CI uses the mirror with an AtomGit
fallback; the mirror is a plain read-only sync and the artifact records the
exact source commit in its `VERSION` file.

- The workflow clones the ONNX Runtime tag **once per version** and caches the
  source archive; all three build jobs download that same archive. This keeps
  the mirror under its rate limit and makes the gnu and musl builds identical.
- Renovate bumps `ORT_VERSION` in `ort.env` from stable `onnxruntime` PyPI
  releases (`minimumReleaseAge` 7 days; prereleases are ignored by Renovate's
  `ignoreUnstable` default). ORT bumps automerge once the pull-request build,
  smoke, and preflight pass; this is intentional for zero-touch updates.
- The pull request builds all three targets and runs the smoke test.
- A push to `main` publishes `v<version>` once, using `SHA256SUMS` and a build
  provenance attestation. Existing releases are never overwritten.
- A failed build (for example an upstream CMake change) leaves the release
  absent; the next run can retry.

`workflow_dispatch` accepts an explicit version and an optional `publish` flag
for bootstrap or break-glass rebuilds.

## Verification

Every target goes through two gates before publishing:

1. **Smoke test**: `smoke/smoke.cc` links `libonnxruntime.a`, loads
   `smoke/tiny_add.onnx`, runs an inference, and checks the output. musl
   binaries are asserted to be statically linked. aarch64 runs natively on an
   arm64 runner.
2. **Consumer preflight**: after packaging, the tarball is extracted and the
   smoke test is linked again with the Alpine GCC 14.2 musl toolchain and
   executed on the matching architecture. This catches a broken archive or
   accidental toolchain drift before publishing.

The smoke model is generated by `smoke/generate_model.py` (requires Python
`onnx`) and checked in; CI does not need Python ML dependencies.

## Building locally

```sh
docker build -f images/alpine.Dockerfile -t ort-build .
docker run --rm -v "$PWD:/src" -w /src \
  -e ORT_VERSION=1.32.0 \
  -e ORT_GIT_URL=https://gitcode.com/GitHub_Trending/on/onnxruntime.git \
  ort-build sh scripts/ci/build-in-container.sh x86_64-unknown-linux-musl
sh scripts/package.sh 1.32.0 x86_64-unknown-linux-musl dist
```

For the GNU target use `images/ubuntu.Dockerfile`. The aarch64 musl target must
build on an aarch64 host.

## Releases are immutable

Tags are `v<onnxruntime-version>`. Assets are never replaced. If an artifact has
to be rebuilt for the same ONNX Runtime version, publish a new version tag or
coordinate a manual pin change; silent replacement would invalidate consumers'
SHA-256 pins.

## License

The build scripts and CI configuration are MIT licensed (see `LICENSE`).
ONNX Runtime is MIT licensed; the release archive includes its `LICENSE` and
`ThirdPartyNotices.txt`.

The musl build recipe (shared library build plus `ar -M` merge of the internal
static archives, and the FlatBuffers `strtoull_l` workaround) was derived from
[RapidAI/OnnxruntimeBuilder](https://github.com/RapidAI/OnnxruntimeBuilder)
(Apache-2.0).
