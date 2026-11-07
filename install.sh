#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZED_CONFIG_DIR="${HOME}/.config/zed"
ZED_SKILLS_DIR="${HOME}/.agents/skills"

echo "[+] Bootstrapping Zed global standards from: $REPO_DIR"

mkdir -p "$ZED_CONFIG_DIR"
if [[ -f "$REPO_DIR/AGENTS.md" ]]; then
    ln -sf "$REPO_DIR/AGENTS.md" "$ZED_CONFIG_DIR/AGENTS.md"
    echo "[+] Linked: $ZED_CONFIG_DIR/AGENTS.md -> $REPO_DIR/AGENTS.md"
fi

mkdir -p "$ZED_SKILLS_DIR"
if [[ -d "$REPO_DIR/skills" ]]; then
    for skill in "$REPO_DIR/skills/"*; do
        if [[ -d "$skill" ]]; then
            skill_name="$(basename "$skill")"
            ln -sfn "$skill" "$ZED_SKILLS_DIR/$skill_name"
            echo "[+] Linked skill: $ZED_SKILLS_DIR/$skill_name -> $skill"
        fi
    done
fi

echo "[+] Bootstrap complete. Zed will now use these standards across all projects."
