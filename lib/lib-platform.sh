#!/usr/bin/env bash
# ==============================================================================
# Platform & Architecture Detection Library
# ==============================================================================

# Returns lowercase kernel name: linux, darwin
detect_os() {
    local os
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    echo "$os"
}

# Returns canonical architecture name: x86_64, aarch64
detect_arch() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64)
            echo "x86_64"
            ;;
        aarch64|arm64)
            echo "aarch64"
            ;;
        *)
            echo "[-] Error: Unsupported CPU architecture: $arch" >&2
            return 1
            ;;
    esac
}

# Returns common Go/binary distribution architecture alias: amd64, arm64
detect_arch_alias() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        *)
            echo "[-] Error: Unsupported CPU architecture: $arch" >&2
            return 1
            ;;
    esac
}

# Returns Rust musl target triple (used by Jujutsu and modern CLI binaries)
detect_musl_target() {
    local os
    os="$(detect_os)"
    if [[ "$os" != "linux" ]]; then
        echo "[-] Error: musl targets only available for Linux." >&2
        return 1
    fi

    local arch
    arch="$(detect_arch)"
    case "$arch" in
        x86_64)
            echo "x86_64-unknown-linux-musl"
            ;;
        aarch64)
            echo "aarch64-unknown-linux-musl"
            ;;
    esac
}
