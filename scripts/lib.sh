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

# Resolve a version from an explicit value or ort.env below the given root.
resolve_version() {
    root=$1
    explicit=${2:-}
    if [ -n "$explicit" ]; then
        version=$(strip_v "$explicit")
    else
        # shellcheck disable=SC1091
        . "$root/ort.env"
        version=$ORT_VERSION
    fi
    validate_version "$version" || return 1
    printf '%s\n' "$version"
}

musl_link_flags() {
    printf '%s\n' "-static -static-libstdc++ -static-libgcc -lpthread -lm"
}
