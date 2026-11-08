#!/usr/bin/env bash
# ==============================================================================
# Deterministic Site Selection Library
# ==============================================================================

resolve_site() {
    local target_site="${1:-}"
    local site_conf_dir="${2:-${REPO_ROOT:-.}/site-conf}"

    if [[ -n "$target_site" ]]; then
        if [[ ! -d "$site_conf_dir/$target_site" ]]; then
            echo "[-] Error: Site profile '$target_site' not found in $site_conf_dir." >&2
            return 1
        fi
        echo "$target_site"
        return 0
    fi

    if [[ ! -d "$site_conf_dir" ]]; then
        echo "[-] Error: site-conf directory not found at $site_conf_dir" >&2
        return 1
    fi

    local sites=($(find "$site_conf_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort))
    if [[ ${#sites[@]} -eq 0 ]]; then
        echo "[-] Error: No site profiles found in $site_conf_dir." >&2
        return 1
    fi

    echo "Select a site profile:" >&2
    for i in "${!sites[@]}"; do
        echo "  $((i+1))) ${sites[$i]}" >&2
    done
    read -rp "Selection [1-${#sites[@]}]: " choice
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#sites[@]} )); then
        echo "[-] Error: Invalid selection '$choice'." >&2
        return 1
    fi
    echo "${sites[$((choice-1))]}"
}

resolve_or_create_site() {
    local target_site="${1:-}"
    local site_conf_dir="${2:-${REPO_ROOT:-.}/site-conf}"

    if [[ -n "$target_site" ]]; then
        echo "$target_site"
        return 0
    fi

    mkdir -p "$site_conf_dir"
    local sites=($(find "$site_conf_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort))

    echo "Select a site profile to manage:" >&2
    local count=0
    for i in "${!sites[@]}"; do
        echo "  $((i+1))) ${sites[$i]}" >&2
        count=$((i+1))
    done
    echo "  $((count+1))) [Create new profile]" >&2

    read -rp "Selection [1-$((count+1))]: " choice
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > count + 1 )); then
        echo "[-] Error: Invalid selection." >&2
        return 1
    fi

    if (( choice == count + 1 )); then
        read -rp "Enter new site profile ID (e.g., lake, prod-east, lab): " new_id
        if [[ -z "$new_id" || ! "$new_id" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo "[-] Error: Invalid site ID '$new_id'. Use alphanumeric, hyphen, or underscore." >&2
            return 1
        fi
        echo "$new_id"
    else
        echo "${sites[$((choice-1))]}"
    fi
}
