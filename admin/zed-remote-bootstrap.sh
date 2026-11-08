#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
PROJECTS_DIR="${HOME}/Projects"

echo "===================================================================="
echo " Bootstrapping Remote Linux Development Host"
echo "===================================================================="

mkdir -p "$BIN_DIR" "$PROJECTS_DIR"

# 1. Install Jujutsu (jj) if not already installed
if ! command -v jj >/dev/null 2>&1; then
    echo "[+] Jujutsu (jj) not found. Installing latest release..."
    LATEST_TAG=$(curl -sSL "https://api.github.com/repos/martinvonz/jj/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    TARBALL="jj-v${LATEST_TAG}-x86_64-unknown-linux-musl.tar.gz"
    DOWNLOAD_URL="https://github.com/martinvonz/jj/releases/download/v${LATEST_TAG}/${TARBALL}"

    TMP_DIR=$(mktemp -d)
    echo "[+] Downloading ${TARBALL}..."
    curl -sSL "$DOWNLOAD_URL" | tar -xz -C "$TMP_DIR"
    install -m 755 "$TMP_DIR/jj" "$BIN_DIR/jj"
    rm -rf "$TMP_DIR"
    echo "[+] Installed Jujutsu (jj) v${LATEST_TAG} to $BIN_DIR/jj"
else
    echo "[+] Jujutsu (jj) is already installed: $(command -v jj)"
fi

# 2. Transparent ~/.bashrc.d Setup for PATH
ensure_bashrc_d_path() {
    local bashrc_d="${HOME}/.bashrc.d"
    local dropin_file="${bashrc_d}/local-bin.bash"

    if [[ ":$PATH:" == *":$BIN_DIR:"* ]] && [[ -f "$dropin_file" ]]; then
        return 0
    fi

    mkdir -p "$bashrc_d"
    cat <<'EOF' > "$dropin_file"
# Add ~/.local/bin to PATH for user-installed binaries
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi
EOF
    echo "[+] Created PATH drop-in: $dropin_file"

    if [[ -f "${HOME}/.bashrc" ]] && ! grep -q '\.bashrc\.d' "${HOME}/.bashrc"; then
        echo ""
        echo "===================================================================="
        echo " [NOTICE] Enable modular ~/.bashrc.d configuration directory?"
        echo "===================================================================="
        echo " Why:     ~/.local/bin needs to be in your PATH for user binaries."
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

        cat <<'EOF' >> "${HOME}/.bashrc"

# Source ~/.bashrc.d drop-ins
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        [ -f "$rc" ] && . "$rc"
    done
    unset rc
fi
EOF
        echo "[+] Updated ~/.bashrc with ~/.bashrc.d loader."
    fi
}

ensure_bashrc_d_path

# 3. Clone or verify zed-standards repository
ZED_STANDARDS_DIR="$PROJECTS_DIR/zed-standards"
if [[ ! -d "$ZED_STANDARDS_DIR" ]]; then
    echo "[+] Cloning zed-standards into $ZED_STANDARDS_DIR..."
    git clone "${ZED_STANDARDS_REPO:-https://github.com/in3x/zed-standards.git}" "$ZED_STANDARDS_DIR" || {
        echo "[-] Note: Update ZED_STANDARDS_REPO if your upstream repo is hosted on a private Gitea/Git server."
    }
else
    echo "[+] zed-standards is present at $ZED_STANDARDS_DIR"
fi

echo ""
echo "===================================================================="
echo "[+] Remote development host bootstrap complete!"
echo "    Next steps:"
echo "    1. Run: source ~/.bashrc (or reopen terminal)"
echo "    2. Clone your development repositories into ~/Projects/<app>"
echo "    3. Link standards into any workspace:"
echo "       $ZED_STANDARDS_DIR/install.sh --project ~/Projects/<app>"
echo "===================================================================="
