#!/usr/bin/env bash
# ==============================================================================
# Safe Deployment & File Installation Library
# ==============================================================================

# Ensures the calling script has root/sudo privileges when required
require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "[-] Error: This deployment script must be run as root (or via sudo)." >&2
        return 1
    fi
}

# Safely installs a file with change detection, interactive diffing, and permissions
install_file_safely() {
    local src="$1"
    local dest="$2"
    local mode="${3:-0644}"
    local owner="${4:-root}"
    local group="${5:-root}"

    if [[ ! -f "$src" ]]; then
        echo "[-] Error: Source file not found: $src" >&2
        return 1
    fi

    mkdir -p "$(dirname "$dest")"

    if [[ -f "$dest" ]]; then
        if cmp -s "$src" "$dest"; then
            echo "   [UNCHANGED] $dest"
            chmod "$mode" "$dest"
            chown "$owner:$group" "$dest" 2>/dev/null || true
            return 0
        fi

        echo "   [DIFF DETECTED] $dest exists and differs from source."

        while true; do
            local choice
            read -r -p "   Action for $dest [y=Overwrite / d=Show diff / n=Skip / c=Cancel]: " choice
            case "$choice" in
                [Dd]*)
                    echo "   --- Diff ($dest -> $src) ---"
                    diff -u "$dest" "$src" || true
                    echo "   ----------------------------"
                    ;;
                [Yy]*)
                    cp "$src" "$dest"
                    chmod "$mode" "$dest"
                    chown "$owner:$group" "$dest" 2>/dev/null || true
                    echo "   [UPDATED] $dest"
                    return 0
                    ;;
                [Nn]*)
                    echo "   [SKIPPED] Left $dest unchanged."
                    return 0
                    ;;
                [Cc]*)
                    echo "[-] Deployment canceled by user." >&2
                    return 1
                    ;;
                *)
                    echo "   Please enter 'y', 'd', 'n', or 'c'."
                    ;;
            esac
        done
    else
        cp "$src" "$dest"
        chmod "$mode" "$dest"
        chown "$owner:$group" "$dest" 2>/dev/null || true
        echo "   [CREATED] $dest"
        return 0
    fi
}
