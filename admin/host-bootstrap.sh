#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="${HOME}/.local/bin"

show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [JJ_OPTIONS]

Bootstraps a Linux host locally with development tools and libraries.

Bootstrap Modes:
      --all             [Audience A] Full interactive setup: installs jj, ~/.bashrc.d,
                        zed-init command, and the shared platform library (default).
  -l, --lib-only, --headless
                        [Audience B] Headless / Production mode: installs jj and the
                        shared platform library (~/.local/lib/dev-bootstrap), omitting
                        interactive Zed agent tools.

Options forwarded to jj-install.sh:
  -v, --version <TAG>   Install a specific Jujutsu version (e.g., v0.47.1).
  -f, --force           Force reinstall even if current version is up to date.
      --user            Install to ~/.local/bin (default).
      --system          Install to /usr/local/bin.
  -d, --dir <PATH>      Target directory for the jj executable.
  -h, --help            Show this help message.
EOF
}

LIB_ONLY=false
FORWARDED_ARGS=()

for arg in "$@"; do
    case "$arg" in
        -h|--help)
            show_help
            exit 0
            ;;
        -l|--lib-only|--headless)
            LIB_ONLY=true
            ;;
        --all)
            LIB_ONLY=false
            ;;
        *)
            FORWARDED_ARGS+=("$arg")
            ;;
    esac
done

echo "===================================================================="
if [[ "$LIB_ONLY" == true ]]; then
    echo " Bootstrapping Local Host for Headless Platform Library (Audience B)"
else
    echo " Bootstrapping Local Host for Development (Audience A)"
fi
echo "===================================================================="

mkdir -p "$BIN_DIR"

# 1. Install or upgrade Jujutsu (jj) to the latest release
echo "[+] Ensuring Jujutsu (jj) is installed and up to date..."
if [[ ! -x "$SCRIPT_DIR/jj-install.sh" ]]; then
    echo "[-] Error: $SCRIPT_DIR/jj-install.sh not found or not executable." >&2
    exit 1
fi

# Forward arguments to jj-install.sh, defaulting to --user if no target mode is specified
JJ_ARGS=()
has_target=false
for arg in "${FORWARDED_ARGS[@]}"; do
    if [[ "$arg" == "--user" || "$arg" == "--system" || "$arg" == "-d" || "$arg" == "--dir" ]]; then
        has_target=true
        break
    fi
done

if [[ "$has_target" == false ]]; then
    JJ_ARGS+=("--user")
fi
JJ_ARGS+=("${FORWARDED_ARGS[@]}")

"$SCRIPT_DIR/jj-install.sh" "${JJ_ARGS[@]}"

# 2. Transparent ~/.bashrc.d Setup
ensure_bashrc_d_loader() {
    local bashrc_d="${HOME}/.bashrc.d"
    mkdir -p "$bashrc_d"

    if [[ -f "${HOME}/.bashrc" ]] && ! grep -q '\.bashrc\.d' "${HOME}/.bashrc"; then
        echo ""
        echo "===================================================================="
        echo " [NOTICE] Enable modular ~/.bashrc.d configuration directory?"
        echo "===================================================================="
        echo " Why:     Enables modular PATH and tool configurations without"
        echo "          polluting or manually editing your ~/.bashrc."
        echo " Benefit: ~/.bashrc.d allows tools to add PATH & environment settings"
        echo "          in separate, clean drop-in files without ever modifying"
        echo "          your main ~/.bashrc again."
        echo " Proposed addition to ~/.bashrc:"
        echo ""
        echo "   # Source ~/.bashrc.d drop-ins"
        echo "   if [ -d ~/.bashrc.d ]; then"
        echo "       for rc in ~/.bashrc.d/*; do"
        echo "           [ -f \"\$rc\" ] && . \"\$rc\""
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
        else
            echo "[-] Skipped updating ~/.bashrc. Left dotfiles unchanged."
            echo "    To manually enable drop-ins, add ~/.bashrc.d loader to ~/.bashrc."
        fi
    fi
}

ensure_bashrc_d_dropins() {
    local bashrc_d="${HOME}/.bashrc.d"
    mkdir -p "$bashrc_d"

    # A. local-bin.bash: clean PATH addition for ~/.local/bin
    local bin_dropin="${bashrc_d}/local-bin.bash"
    cat <<'EOF' > "$bin_dropin"
# Add ~/.local/bin to PATH for user-installed binaries
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi
EOF
    echo "[+] Created PATH drop-in: $bin_dropin"

    # B. zed-standards.bash: clean zed-init function (only for full interactive Audience A)
    if [[ "$LIB_ONLY" == false ]]; then
        local zed_dropin="${bashrc_d}/zed-standards.bash"
        cat <<EOF > "$zed_dropin"
# Zed Standards quick project initializer
# Usage: zed-init [project-path] (defaults to current directory)
zed-init() {
    local target="\${1:-.}"
    local install_script="${REPO_ROOT}/install.sh"
    if [[ ! -x "\$install_script" ]]; then
        echo "[-] Error: \$install_script not found or not executable." >&2
        return 1
    fi
    "\$install_script" --project "\$target"
}
EOF
        echo "[+] Created zed-init drop-in: $zed_dropin"
    fi
}

ensure_bashrc_d_loader
ensure_bashrc_d_dropins

# 3. Link dev-bootstrap shared library into ~/.local/lib/dev-bootstrap
link_dev_bootstrap_lib() {
    local lib_dir="${HOME}/.local/lib"
    local target_symlink="${lib_dir}/dev-bootstrap"

    mkdir -p "$lib_dir"
    ln -sfn "$REPO_ROOT/lib" "$target_symlink"
    echo "[+] Linked shared library: $target_symlink -> $REPO_ROOT/lib"
}

link_dev_bootstrap_lib

echo ""
echo "===================================================================="
if [[ "$LIB_ONLY" == true ]]; then
    echo "[+] Headless platform library host bootstrap complete!"
    echo "    Shared library available at: ~/.local/lib/dev-bootstrap/"
    echo "    Reload shell with: source ~/.bashrc"
else
    echo "[+] Development host bootstrap complete!"
    echo "    Next steps:"
    echo "    1. Run: source ~/.bashrc (or reopen terminal)"
    echo "    2. Clone your development repositories into ~/Projects/<app>"
    echo "    3. Link standards into any workspace effortlessly:"
    echo "       cd ~/Projects/<app> && zed-init"
fi
echo "===================================================================="
