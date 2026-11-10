---
name: script-conventions
description: Detailed standards for authoring operational and administrative Bash scripts, CLI flags, safety checks, menu fallbacks, path verification, and ~/.bashrc.d bootstrapping.
---

# Bash Scripting Conventions

## 1. Script Categorization
- **Application / Operational Scripts** (`scripts/`):
  - Do the direct runtime work of the package.
  - Run unattended via systemd, cron, or unprivileged service accounts (`git`, `app`).
- **Management / Administrative Scripts** (`admin/`):
  - Handle deployment, site profile management (`site-profile.sh`), and binary upgrades.
  - Run interactively by an administrator with `sudo` privileges.

## 2. Naming Standard
- Format: `<app>-<function>.sh` (e.g., `gitea-backup.sh`, `site-profile.sh`, `jj-install.sh`).
- Keep scripts focused on a single function or tightly coupled set of operations.

## 3. Interpreter & Safety Preamble
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
```

## 4. Deterministic Site Selection (CLI Argument or Menu Fallback)
```bash
resolve_site() {
    local target_site="${1:-}"
    if [[ -n "$target_site" ]]; then
        if [[ ! -d "$REPO_ROOT/site-conf/$target_site" ]]; then
            echo "[-] Error: Site profile 'site-conf/$target_site' does not exist." >&2
            exit 1
        fi
        echo "$target_site"
        return
    fi

    local sites=($(find "$REPO_ROOT/site-conf" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort))
    if [[ ${#sites[@]} -eq 0 ]]; then
        echo "[-] Error: No site profiles found in site-conf/." >&2
        exit 1
    fi

    echo "Select a site profile:" >&2
    for i in "${!sites[@]}"; do
        echo "  $((i+1))) ${sites[$i]}" >&2
    done
    read -rp "Selection [1-${#sites[@]}]: " choice
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#sites[@]} )); then
        echo "[-] Invalid selection." >&2
        exit 1
    fi
    echo "${sites[$((choice-1))]}"
}
```

## 5. Transparent PATH & `~/.bashrc.d` Bootstrapping
When installing binaries into directories not yet in the user's `$PATH` (e.g., `~/.local/bin` or `/opt/<project>/bin`):
**Never touch `~/.bashrc` silently.** Always explain what is happening, why, how it benefits the user, and ask for explicit confirmation before editing dotfiles.

```bash
ensure_bashrc_d_dropin() {
    local project_name="$1"
    local bin_dir="$2"
    local bashrc_d="${HOME}/.bashrc.d"
    local dropin_file="${bashrc_d}/${project_name}.bash"

    if [[ ":$PATH:" == *":$bin_dir:"* ]]; then
        return 0
    fi

    mkdir -p "$bashrc_d"

    # 1. Create the application drop-in file
    cat <<EOF > "$dropin_file"
# PATH configuration for ${project_name}
if [[ ":\$PATH:" != *":${bin_dir}:"* ]]; then
    export PATH="${bin_dir}:\$PATH"
fi
EOF
    echo "[+] Created drop-in: $dropin_file"

    # 2. Check if ~/.bashrc already loads ~/.bashrc.d
    if [[ -f "${HOME}/.bashrc" ]] && ! grep -q '\.bashrc\.d' "${HOME}/.bashrc"; then
        echo ""
        echo "===================================================================="
        echo " [NOTICE] Enable modular ~/.bashrc.d configuration directory?"
        echo "===================================================================="
        echo " Why:     ${bin_dir} needs to be in your PATH to run ${project_name}."
        echo " Benefit: ~/.bashrc.d allows tools to add PATH & environment settings"
        echo "          in separate, clean drop-in files without ever modifying"
        echo "          your main ~/.bashrc again."
        echo " Proposed addition to ~/.bashrc:"
        echo ""
        echo "   # Source ~/.bashrc.d drop-ins"
        echo "   if [ -d ~/.bashrc.d ]; then"
        echo "       for rc in ~/.bashrc.d/*; do"
        echo "           [ -f "\\$rc" ] && . "\\$rc""
        echo "       done"
        echo "       unset rc"
        echo "   fi"
        echo "===================================================================="
        read -rp "Append this loader block to ~/.bashrc now? [y/N]: " confirm_bashrc
        if [[ "$confirm_bashrc" =~ ^[Yy]$ ]]; then
            cat <<'EOF' >> "${HOME}/.bashrc"

# Source ~/.bashrc.d drop-ins
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        [ -f "$rc" ] && . "$rc"
    done
    unset rc
fi
EOF
            echo "[+] Updated ~/.bashrc successfully."
            echo "[!] Run 'source ~/.bashrc' or open a new terminal to update your PATH."
        else
            echo "[-] Skipped updating ~/.bashrc. Left dotfiles unchanged."
            echo "    To manually enable ${project_name}, add to your PATH:"
            echo "      export PATH="${bin_dir}:\$PATH""
        fi
    else
        echo "[!] Drop-in active. Run 'source ~/.bashrc' to refresh PATH."
    fi
}
```

## 6. Privilege Handling & Logging
- Clearly display target paths (root mode vs. user mode).
- Standard progress: `echo "[+] ..."`
- Error reporting: `echo "[-] Error: ..." >&2`
- Syslog / journal logging: `logger -t <tag>` for background jobs.

## 7. Command Reference Linking Standard
Whenever an operational or administrative script is introduced or referenced in READMEs, guides, or operational docs:
1. **Format as an inline anchor link**: [`admin/<script>.sh`](#admin<script>sh).
2. **Provide a matching Command/CLI Reference section**:
   - Exact syntax & option flags.
   - Purpose, side effects, and required privileges (root vs. user).
   - Practical invocation examples.
3. **Principle**: Keep high-level workflows clean while giving operators instant click-through access to full command mechanics.
