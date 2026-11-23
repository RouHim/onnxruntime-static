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

case "$target" in
    x86_64-*) processor=x86_64 ;;
    aarch64-*) processor=aarch64 ;;
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
        if [ ! -f "$src/$file" ]; then
            echo "error: ONNX Runtime source is missing $file" >&2
            exit 1
        fi
        cp "$src/$file" "$out/$file"
    done
    if [ -f "$src/SOURCE_COMMIT" ]; then
        commit=$(cat "$src/SOURCE_COMMIT")
    else
        commit=$(git -C "$src" rev-parse HEAD)
    fi
    printf 'version=%s\ncommit=%s\n' "$version" "$commit" > "$out/VERSION"
}

clone_ort() {
    attempt=1
    while [ "$attempt" -le 3 ]; do
        if git clone --quiet --depth 1 --branch "v$version" "$git_url" "$src"; then
            return 0
        fi
        rm -rf "$src"
        attempt=$((attempt + 1))
        if [ "$attempt" -le 3 ]; then
            sleep 5
        fi
    done
    return 1
}

echo "==> cloning ONNX Runtime v$version ($target)"
if [ -n "${ORT_SOURCE_DIR:-}" ]; then
    src=$ORT_SOURCE_DIR
else
    src="$work/src"
    git_url=${ORT_GIT_URL:-https://gitcode.com/GitHub_Trending/on/onnxruntime.git}
    clone_ort
fi

echo "==> patching ONNX Runtime"
werror_patch="$root/patches/onnxruntime-disable-werror.patch"
if patch -p1 -d "$src" --dry-run -i "$werror_patch" >/dev/null 2>&1; then
    patch -p1 -d "$src" -i "$werror_patch"
elif grep -q 'COMPILE_WARNING_AS_ERROR OFF' "$src/cmake/CMakeLists.txt"; then
    echo "werror patch already present"
else
    echo "error: werror patch does not apply" >&2
    exit 1
fi

echo "==> configuring"
set -- -S "$src/cmake" -B "$build" -G "Unix Makefiles" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_PROCESSOR="$processor" \
    -DCMAKE_INSTALL_PREFIX="$install"
while IFS= read -r option; do
    case "$option" in
        ''|'#'*) continue ;;
    esac
    set -- "$@" "$option"
done < "$root/cmake/options.txt"

# The messense/rust-musl-cross images export TARGET_CXX; use their GCC 12.4
# musl toolchain so the artifact links with turbo-pix's release builder.
if [ -n "${TARGET_CXX:-}" ]; then
    set -- "$@" \
        -Donnxruntime_CROSS_COMPILING=ON \
        -DCMAKE_TOOLCHAIN_FILE="$root/cmake/musl-cross.toolchain.cmake"
else
    set -- "$@" -Donnxruntime_CROSS_COMPILING=OFF
fi
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
