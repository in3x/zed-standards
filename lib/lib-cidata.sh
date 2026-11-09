#!/usr/bin/env bash
# ==============================================================================
# NoCloud Cloud-Init ISO Generation Library
# Builds NoCloud cidata ISO images for KVM, XCP-ng, TrueNAS, and Proxmox
# ==============================================================================

build_nocloud_iso() {
    local user_data="$1"
    local meta_data="$2"
    local output_iso="$3"

    if [[ ! -f "$user_data" ]]; then
        echo "[-] Error: user-data file not found at $user_data" >&2
        return 1
    fi

    if [[ ! -f "$meta_data" ]]; then
        echo "[-] Error: meta-data file not found at $meta_data" >&2
        return 1
    fi

    mkdir -p "$(dirname "$output_iso")"

    local iso_cmd=""
    if command -v genisoimage &>/dev/null; then
        iso_cmd="genisoimage -output $output_iso -volid cidata -rational-rock -translation-table"
    elif command -v mkisofs &>/dev/null; then
        iso_cmd="mkisofs -output $output_iso -volid cidata -rational-rock -translation-table"
    elif command -v xorrisofs &>/dev/null; then
        iso_cmd="xorrisofs -output $output_iso -volid cidata -rational-rock"
    else
        echo "[-] Error: Neither genisoimage, mkisofs, nor xorriso is installed." >&2
        echo "    Install on Ubuntu/Debian with: sudo apt-get install -y genisoimage" >&2
        return 1
    fi

    echo "[+] Building NoCloud ISO: $output_iso"
    $iso_cmd -J "$user_data" "$meta_data" >/dev/null 2>&1
    echo "[OK] Created ISO: $output_iso"
}
