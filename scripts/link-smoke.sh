#!/bin/sh
# Compile the smoke test against an artifact directory.
#
# Usage: link-smoke.sh <cxx> <artifact-dir> <output> [link flags...]
set -eu

[ $# -ge 3 ] || {
    echo "usage: scripts/link-smoke.sh <cxx> <artifact-dir> <output> [flags...]" >&2
    exit 2
}
cxx=$1
out=$2
bin=$3
shift 3

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
"$cxx" -std=c++17 -O2 \
    -I "$out/include" -I "$out/include/onnxruntime" -I "$out/include/core/session" \
    "$root/smoke/smoke.cc" \
    -L "$out/lib" -lonnxruntime "$@" \
    -o "$bin"
