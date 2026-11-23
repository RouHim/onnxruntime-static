#!/bin/sh
# Shared helpers for version validation, target naming, and artifact names.

# Accept only bare stable versions: MAJOR.MINOR.PATCH.
validate_version() {
    printf '%s\n' "$1" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'
}

strip_v() {
    printf '%s\n' "${1#v}"
}

# Asset names carry the version because Renovate's
# `github-release-attachments` datasource maps a digest back to its asset by
# replacing the old version string in the filename.
asset_name() {
    printf 'onnxruntime-%s-%s-static.tar.zst\n' "$1" "$2"
}

# GCC prefix used by the messense/rust-musl-cross images for the link
# preflight. The images ship target-prefixed tools such as
# `aarch64-unknown-linux-musl-g++`. The gnu target links with the host
# compiler, so it has none.
compiler_prefix() {
    case "$1" in
        x86_64-unknown-linux-musl|aarch64-unknown-linux-musl) printf '%s\n' "$1" ;;
        *) return 1 ;;
    esac
}
