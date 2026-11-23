#!/bin/sh
# Compile and run the C++ smoke test against a built artifact directory.
set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root=$(dirname "$here")

[ $# -ge 1 ] || {
    echo "usage: scripts/smoke.sh <target> [artifact-dir]" >&2
    exit 2
}
target=$1
out=${2:-"$root/out/$target"}

case "$target" in
    x86_64-unknown-linux-gnu)
        link_flags="-lpthread -ldl -lm"
        ;;
    x86_64-unknown-linux-musl|aarch64-unknown-linux-musl)
        link_flags="-static -static-libstdc++ -static-libgcc -lpthread -lm"
        ;;
    *)
        echo "unsupported target: $target" >&2
        exit 2
        ;;
esac

mkdir -p "$root/build"
bin="$root/build/smoke-$target"
cxx=${CXX:-${TARGET_CXX:-g++}}
# shellcheck disable=SC2086
sh "$root/scripts/link-smoke.sh" "$cxx" "$out" "$bin" $link_flags

if [ "$target" != x86_64-unknown-linux-gnu ]; then
    file "$bin" | grep -q 'statically linked' || {
        echo "smoke binary is not statically linked:" >&2
        file "$bin" >&2
        exit 1
    }
fi

"$bin" "$root/smoke/tiny_add.onnx"
