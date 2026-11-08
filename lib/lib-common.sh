#!/usr/bin/env bash
# ==============================================================================
# dev-bootstrap Common Platform Library Loader
# Sources platform detection, site resolution, and deployment primitives
# ==============================================================================

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for lib_script in "$LIB_DIR"/lib-*.sh; do
    if [[ "$lib_script" != "${BASH_SOURCE[0]}" && -f "$lib_script" ]]; then
        source "$lib_script"
    fi
done
