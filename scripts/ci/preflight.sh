#!/bin/sh
# Link the smoke test with the GCC 12.4 musl toolchain used by the consumer
# (turbo-pix). A missing libstdc++ symbol fails here instead of in the
# consumer's build.
set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH='' cd -- "$here/../.." && pwd)
. "$root/scripts/lib.sh"

[ $# -eq 1 ] || {
    echo "usage: scripts/ci/preflight.sh <target>" >&2
    exit 2
}
target=$1

version_input=${ORT_VERSION:-}
if [ -n "$version_input" ]; then
    version=$(strip_v "$version_input")
else
    version=$(sh "$root/scripts/resolve-version.sh")
fi
asset=$(asset_name "$version" "$target")
archive="$root/dist/$asset"
if [ ! -f "$archive" ]; then
    echo "artifact not found: $archive" >&2
    exit 1
fi

out="$root/out/$target"
rm -rf "$out"
mkdir -p "$out"
tar --zstd -xf "$archive" -C "$out"

prefix=$(compiler_prefix "$target")
bin="$root/build/preflight-$target"
mkdir -p "$root/build"
sh "$root/scripts/link-smoke.sh" "${prefix}-g++" "$out" "$bin" \
    -static -static-libstdc++ -static-libgcc -lpthread -lm

file "$bin" | grep -q 'statically linked' || {
    echo "preflight binary is not statically linked:" >&2
    file "$bin" >&2
    exit 1
}

# The x86_64 toolchain runs on this host, so execute the binary too.
if [ "$target" = x86_64-unknown-linux-musl ]; then
    "$bin" "$root/smoke/tiny_add.onnx"
fi

echo "preflight link ok ($target)"
