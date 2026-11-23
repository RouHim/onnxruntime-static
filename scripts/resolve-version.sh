#!/bin/sh
# Resolve the ONNX Runtime version: explicit argument, else ort.env.
set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root=$(dirname "$here")
. "$root/scripts/lib.sh"

version=${1:-}
if [ -z "$version" ]; then
    # shellcheck disable=SC1091
    . "$root/ort.env"
    version=$ORT_VERSION
fi

version=$(strip_v "$version")
if ! validate_version "$version"; then
    echo "invalid ONNX Runtime version: $version" >&2
    exit 2
fi
printf '%s\n' "$version"
