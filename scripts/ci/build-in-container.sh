#!/bin/sh
# Build and smoke-test one target inside a build image.
set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH='' cd -- "$here/../.." && pwd)
. "$root/scripts/lib.sh"

[ $# -eq 1 ] || {
    echo "usage: scripts/ci/build-in-container.sh <target>" >&2
    exit 2
}
target=$1

if [ -n "${ORT_VERSION:-}" ]; then
    version=$(strip_v "$ORT_VERSION")
else
    version=$(sh "$root/scripts/resolve-version.sh")
fi

out="$root/out/$target"
sh "$root/scripts/build-ort.sh" "$version" "$target" "$out"
sh "$root/scripts/smoke.sh" "$target" "$out"

# The container runs as root; make the workspace readable for the host steps.
chmod -R a+rX "$root/out"
