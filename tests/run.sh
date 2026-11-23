#!/bin/sh
# Unit tests for the pure shell helpers and the version resolver.
set -eu

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root=$(dirname "$here")
. "$root/scripts/lib.sh"

failures=0

assert_eq() {
    expected=$1
    actual=$2
    label=$3
    if [ "$expected" != "$actual" ]; then
        echo "FAIL: $label: expected '$expected', got '$actual'" >&2
        failures=$((failures + 1))
    fi
}

assert_ok() {
    label=$1
    shift
    if ! "$@" >/dev/null 2>&1; then
        echo "FAIL: $label: expected success" >&2
        failures=$((failures + 1))
    fi
}

assert_fails() {
    label=$1
    shift
    if "$@" >/dev/null 2>&1; then
        echo "FAIL: $label: expected failure" >&2
        failures=$((failures + 1))
    fi
}

assert_eq "1.32.0" "$(strip_v v1.32.0)" "strip_v removes the v prefix"
assert_eq "1.32.0" "$(strip_v 1.32.0)" "strip_v keeps bare versions"

assert_ok "validate_version accepts 1.32.0" validate_version 1.32.0
assert_fails "validate_version rejects a v prefix" validate_version v1.32.0
assert_fails "validate_version rejects a short version" validate_version 1.32
assert_fails "validate_version rejects a prerelease" validate_version 1.32.0-rc.1

assert_eq "onnxruntime-1.32.0-x86_64-unknown-linux-musl-static.tar.zst" \
    "$(asset_name 1.32.0 x86_64-unknown-linux-musl)" \
    "asset_name embeds the version and target"

assert_eq "x86_64-linux-musl" "$(compiler_prefix x86_64-unknown-linux-musl)" \
    "compiler_prefix maps x86_64 musl"
assert_eq "aarch64-linux-musl" "$(compiler_prefix aarch64-unknown-linux-musl)" \
    "compiler_prefix maps aarch64 musl"
assert_fails "compiler_prefix rejects the gnu target" compiler_prefix x86_64-unknown-linux-gnu

pinned=$(sh "$root/scripts/resolve-version.sh")
assert_ok "pinned version is valid" validate_version "$pinned"
assert_eq "$(sed -n 's/^ORT_VERSION=//p' "$root/ort.env")" "$pinned" \
    "resolve-version uses ort.env when no argument is given"
assert_eq "1.30.0" "$(sh "$root/scripts/resolve-version.sh" v1.30.0)" \
    "resolve-version strips an explicit v prefix"
assert_fails "resolve-version rejects an invalid explicit version" \
    sh "$root/scripts/resolve-version.sh" latest

if [ "$failures" -ne 0 ]; then
    echo "$failures test(s) failed" >&2
    exit 1
fi
echo "all shell tests passed"
