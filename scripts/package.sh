#!/bin/sh
# Package an artifact directory as the release tarball.
set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root=$(dirname "$here")
. "$root/scripts/lib.sh"

[ $# -ge 2 ] || {
    echo "usage: scripts/package.sh <version> <target> [dist-dir]" >&2
    exit 2
}
version=$(strip_v "$1")
target=$2
dist=${3:-dist}

if ! validate_version "$version"; then
    echo "invalid ONNX Runtime version: $version" >&2
    exit 2
fi
if [ ! -d "$root/out/$target" ]; then
    echo "artifact directory missing: $root/out/$target" >&2
    exit 1
fi

mkdir -p "$dist"
case "$dist" in
    /*) dist_dir=$dist ;;
    *) dist_dir="$root/$dist" ;;
esac
mkdir -p "$dist_dir"
asset=$(asset_name "$version" "$target")
target_file="$dist_dir/$asset"
tar --zstd --sort=name --mtime='UTC 2020-01-01' \
    --owner=0 --group=0 --numeric-owner \
    -cf "$target_file" -C "$root/out/$target" .
printf '%s\n' "$target_file"
