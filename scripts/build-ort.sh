#!/bin/sh
# Build a static ONNX Runtime archive from source.
#
# Runs inside a Linux container with cmake, git, patch, ar/ranlib, and a C++
# compiler. x86_64 targets build on x86_64; aarch64-unknown-linux-musl builds
# natively on aarch64.
set -eu

usage() {
    cat >&2 <<'EOF'
usage: scripts/build-ort.sh <version> <target> <outdir>

targets:
  x86_64-unknown-linux-gnu
  x86_64-unknown-linux-musl
  aarch64-unknown-linux-musl
EOF
    exit 2
}

[ $# -eq 3 ] || usage
version=$1
target=$2
out=$3

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root=$(dirname "$here")
. "$root/scripts/lib.sh"

if ! validate_version "$version"; then
    echo "invalid ONNX Runtime version: $version" >&2
    exit 2
fi
case "$target" in
    x86_64-unknown-linux-gnu|x86_64-unknown-linux-musl|aarch64-unknown-linux-musl) ;;
    *)
        echo "unsupported target: $target" >&2
        exit 2
        ;;
esac
case "$out" in
    ''|/|.)
        echo "refusing to clear output directory: $out" >&2
        exit 2
        ;;
esac

work="$root/build/$target"
src="$work/src"
build="$work/build"
install="$work/install"

rm -rf "$work" "$out"
mkdir -p "$work" "$out/lib" "$out/include"

patch_flatbuffers() {
    patch_file="$root/patches/flatbuffers-musl.patch"
    base="$build/_deps/flatbuffers-src/include/flatbuffers/base.h"
    if patch -p1 -d "$build" --dry-run -i "$patch_file" >/dev/null 2>&1; then
        patch -p1 -d "$build" -i "$patch_file"
    elif [ -f "$base" ] && grep -q 'defined(GLIBC)' "$base"; then
        echo "flatbuffers musl patch already present"
    else
        echo "error: flatbuffers musl patch does not apply" >&2
        exit 1
    fi
}

merge_static_libs() {
    link_txt=$(find "$build" -path '*/CMakeFiles/onnxruntime.dir/link.txt' -print -quit)
    if [ -z "$link_txt" ]; then
        echo "error: CMakeFiles/onnxruntime.dir/link.txt not found" >&2
        exit 1
    fi
    archive="$out/lib/libonnxruntime.a"
    mri="$work/onnxruntime.mri"
    rm -f "$archive"
    printf 'create %s\n' "$archive" > "$mri"
    tr ' ' '\n' < "$link_txt" | while IFS= read -r token; do
        case "$token" in
            *lib*.a) ;;
            *) continue ;;
        esac
        case "$token" in
            /*) lib=$token ;;
            *) lib="$build/$token" ;;
        esac
        if [ -f "$lib" ]; then
            printf 'addlib %s\n' "$lib" >> "$mri"
        fi
    done
    printf 'save\nend\n' >> "$mri"
    ar -M < "$mri"
    ranlib "$archive"
    if [ ! -s "$archive" ]; then
        echo "error: merged archive is empty" >&2
        exit 1
    fi
}

collect_headers() {
    if [ -d "$install/include/onnxruntime" ]; then
        cp -a "$install/include/onnxruntime/." "$out/include/"
    else
        cp -a "$install/include/." "$out/include/"
    fi
}

collect_licenses() {
    for file in LICENSE ThirdPartyNotices.txt; do
        if [ -f "$src/$file" ]; then
            cp "$src/$file" "$out/$file"
        fi
    done
    printf '%s\n' "$version" > "$out/VERSION"
}

echo "==> cloning ONNX Runtime v$version ($target)"
git clone --quiet --depth 1 --branch "v$version" \
    --recurse-submodules --shallow-submodules \
    https://github.com/microsoft/onnxruntime.git "$src"

echo "==> configuring"
set -- -S "$src/cmake" -B "$build" -G "Unix Makefiles" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$install"
while IFS= read -r option; do
    case "$option" in
        ''|'#'*) continue ;;
    esac
    set -- "$@" "$option"
done < "$root/cmake/options.txt"
cmake "$@"

if [ "$target" != x86_64-unknown-linux-gnu ]; then
    echo "==> applying musl patch"
    patch_flatbuffers
fi

echo "==> building"
cmake --build "$build" --parallel "$(nproc)"

echo "==> installing"
cmake --install "$build"

echo "==> merging static libraries"
merge_static_libs

echo "==> collecting headers and licenses"
collect_headers
collect_licenses

echo "built $out"
