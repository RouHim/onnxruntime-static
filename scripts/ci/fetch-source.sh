#!/bin/sh
# Clone one ONNX Runtime tag and pack it for the build jobs.
#
# CI clones once per version; all three builds consume the same source
# artifact. The mirror is rate-limited, so retries and HTTP/1.1 are used.
set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH='' cd -- "$here/../.." && pwd)
. "$root/scripts/lib.sh"

[ $# -eq 2 ] || {
    echo "usage: scripts/ci/fetch-source.sh <version> <destination>" >&2
    exit 2
}
version=$(strip_v "$1")
dest=$2
validate_version "$version" || {
    echo "invalid ONNX Runtime version: $version" >&2
    exit 2
}

case "$dest" in
    ''|/|.) echo "refusing to clear destination: $dest" >&2; exit 2 ;;
esac

rm -rf "$dest"
mkdir -p "$dest"
src="$dest/onnxruntime"

clone_attempt() {
    url=$1
    attempt=1
    while [ "$attempt" -le 3 ]; do
        if git -c http.version=HTTP/1.1 clone --quiet --depth 1 \
            --branch "v$version" "$url" "$src"; then
            return 0
        fi
        rm -rf "$src"
        attempt=$((attempt + 1))
        sleep $((attempt * 3))
    done
    return 1
}

primary=${ORT_GIT_URL:-https://gitcode.com/GitHub_Trending/on/onnxruntime.git}
fallback=${ORT_GIT_FALLBACK_URL:-}
if ! clone_attempt "$primary"; then
    if [ -z "$fallback" ]; then
        echo "failed to clone ONNX Runtime v$version from $primary" >&2
        exit 1
    fi
    echo "primary mirror failed; trying $fallback" >&2
    clone_attempt "$fallback" || {
        echo "failed to clone ONNX Runtime v$version from mirrors" >&2
        exit 1
    }
fi

commit=$(git -C "$src" rev-parse HEAD)
printf '%s\n' "$commit" > "$src/SOURCE_COMMIT"
printf 'version=%s\ncommit=%s\n' "$version" "$commit" > "$src/SOURCE_VERSION"

tar --zstd --sort=name --mtime='UTC 2020-01-01' \
    --owner=0 --group=0 --numeric-owner \
    --exclude='./.git' \
    --exclude='./onnxruntime/test' \
    -cf "$dest/ort-source.tar.zst" -C "$src" .

echo "fetched ONNX Runtime v$version ($commit)"
