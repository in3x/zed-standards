#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [PROJECT_PATH]

Profiles & Options:
  -p, --project <path>   [Audience A] Link standards (skills and AGENTS.md) into a project workspace.
                         Defaults to current working directory if path is omitted.
  -c, --clean, --unlink <path>
                         Safely remove zed-standards symlinks from a project workspace
                         without deleting native project files or non-standards skills.
                         Defaults to current working directory if path is omitted.
  -a, --all, -g, --global
                         [Audience A] Full host setup: links skills, AGENTS.md,
                         and the shared platform library (~/.local/lib/dev-bootstrap).
  -l, --lib-only, --headless
                         [Audience B] Install ONLY the shared platform library
                         (~/.local/lib/dev-bootstrap). Skips editor skills and AI instructions.
                         Ideal for production servers, CI/CD runners, and headless automation.
  -h, --help             Show this help message.

Examples:
  $(basename "$0") --project .                 # Link into current repository
  $(basename "$0") --project ~/Projects/my-app # Link into specific project
  $(basename "$0") --clean .                   # Remove zed-standards symlinks from current project
  $(basename "$0") --all                       # Full host install (skills + library)
  $(basename "$0") --lib-only                  # Headless server library install
EOF
}

link_project() {
    local raw_target="${1:-.}"
    if [[ ! -d "$raw_target" ]]; then
        echo "[-] Error: Project directory '$raw_target' does not exist." >&2
        exit 1
    fi

    local target_proj
    target_proj="$(cd "$raw_target" && pwd)"

    echo "[+] Linking Zed standards to project: $target_proj"

    # 1. Project Skills (.agents/skills/<skill-name>)
    local proj_skills_dir="$target_proj/.agents/skills"
    mkdir -p "$proj_skills_dir"

    if [[ -d "$REPO_DIR/skills" ]]; then
        for skill in "$REPO_DIR/skills/"*; do
            if [[ -d "$skill" ]]; then
                local skill_name
                skill_name="$(basename "$skill")"
                local dest_skill="$proj_skills_dir/$skill_name"

                if [[ -L "$dest_skill" ]]; then
                    ln -sfn "$skill" "$dest_skill"
                    echo "    [+] Refreshed skill: .agents/skills/$skill_name -> $skill"
                elif [[ -e "$dest_skill" ]]; then
                    echo "    [!] Notice: .agents/skills/$skill_name is a local directory (left untouched)."
                else
                    ln -s "$skill" "$dest_skill"
                    echo "    [+] Linked skill: .agents/skills/$skill_name -> $skill"
                fi
            fi
        done
    fi

    # 2. AGENTS.md (Non-destructive)
    local target_agents="$target_proj/AGENTS.md"
    if [[ -L "$target_agents" ]]; then
        ln -sf "$REPO_DIR/AGENTS.md" "$target_agents"
        echo "    [+] Refreshed symlink: AGENTS.md -> $REPO_DIR/AGENTS.md"
    elif [[ -e "$target_agents" ]]; then
        echo "    [!] Notice: Project has an existing AGENTS.md file (left untouched)."
    else
        ln -s "$REPO_DIR/AGENTS.md" "$target_agents"
        echo "    [+] Linked AGENTS.md -> $REPO_DIR/AGENTS.md"
    fi

    # 3. Prevent Git / Jujutsu working-copy pollution
    # In Jujutsu (.jj) repositories, unignored files are auto-snapshotted into commits.
    # We must register patterns in .gitignore to prevent accidental check-ins.
    if [[ -d "$target_proj/.jj" ]] || [[ -f "$target_proj/.gitignore" ]]; then
        local gitignore_file="$target_proj/.gitignore"
        touch "$gitignore_file"
        for pattern in ".agents/" "AGENTS.md" ".zed/"; do
            if ! grep -qxF "$pattern" "$gitignore_file" 2>/dev/null; then
                echo "$pattern" >> "$gitignore_file"
                echo "    [+] Registered '$pattern' in .gitignore"
            fi
        done
    fi

    if [[ -d "$target_proj/.git" ]]; then
        local exclude_file="$target_proj/.git/info/exclude"
        mkdir -p "$(dirname "$exclude_file")"
        for pattern in ".agents/" "AGENTS.md" ".zed/"; do
            if ! grep -qxF "$pattern" "$exclude_file" 2>/dev/null; then
                echo "$pattern" >> "$exclude_file"
                echo "    [+] Registered '$pattern' in .git/info/exclude"
            fi
        done
    fi

    echo "[+] Project setup complete for: $target_proj"
}
clean_project() {
    local raw_target="${1:-.}"
    if [[ ! -d "$raw_target" ]]; then
        echo "[-] Error: Project directory '$raw_target' does not exist." >&2
        exit 1
    fi

    local target_proj
    target_proj="$(cd "$raw_target" && pwd)"

    echo "[*] Cleaning zed-standards links from: $target_proj"

    # 1. Safely remove AGENTS.md ONLY if it points to zed-standards
    local target_agents="$target_proj/AGENTS.md"
    if [[ -L "$target_agents" ]]; then
        local target
        target="$(readlink "$target_agents" || true)"
        if [[ "$target" == *"/zed-standards/"* || "$target" == *"zed-standards"* ]]; then
            rm -f "$target_agents"
            echo "    [-] Removed zed-standards symlink: AGENTS.md"
        else
            echo "    [=] Kept external symlink: AGENTS.md -> $target"
        fi
    elif [[ -e "$target_agents" ]]; then
        echo "    [=] Kept project-native file: AGENTS.md"
    fi

    # 2. Safely remove ONLY individual skills pointing to zed-standards
    local proj_skills_dir="$target_proj/.agents/skills"
    if [[ -d "$proj_skills_dir" ]]; then
        for skill in "$proj_skills_dir"/*; do
            if [[ -L "$skill" ]]; then
                local target
                target="$(readlink "$skill" || true)"
                if [[ "$target" == *"/zed-standards/"* || "$target" == *"zed-standards"* ]]; then
                    rm -f "$skill"
                    echo "    [-] Removed zed-standards skill: $(basename "$skill")"
                else
                    echo "    [=] Kept external symlink: $(basename "$skill") -> $target"
                fi
            elif [[ -e "$skill" ]]; then
                echo "    [=] Kept project-native skill: $(basename "$skill")"
            fi
        done

        # Clean up empty parent directories if nothing else remains
        rmdir "$proj_skills_dir" 2>/dev/null || true
        rmdir "$target_proj/.agents" 2>/dev/null || true
    fi

    echo "[+] Project cleanup complete for: $target_proj"
}


link_lib_only() {
    local user_lib_dir="${HOME}/.local/lib"
    local target_symlink="${user_lib_dir}/dev-bootstrap"

    echo "[+] Installing dev-bootstrap shared platform library (Audience B / Headless)..."
    mkdir -p "$user_lib_dir"
    ln -sfn "$REPO_DIR/lib" "$target_symlink"
    echo "    [+] Linked: $target_symlink -> $REPO_DIR/lib"
    echo "    Available modules:"
    for mod in "$REPO_DIR/lib"/lib-*.sh; do
        [[ -f "$mod" ]] && echo "      - $(basename "$mod")"
    done
    echo "[+] Platform library ready at: $target_symlink"
}

link_global() {
    local zed_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/zed"
    local zed_skills_dir="${HOME}/.agents/skills"

    echo "[+] Bootstrapping Zed global standards to: $HOME"
    echo "    Config dir: $zed_config_dir"
    echo "    Skills dir: $zed_skills_dir"

    mkdir -p "$zed_config_dir"
    local global_agents="$zed_config_dir/AGENTS.md"
    if [[ -L "$global_agents" ]]; then
        ln -sf "$REPO_DIR/AGENTS.md" "$global_agents"
        echo "    [+] Refreshed: $global_agents -> $REPO_DIR/AGENTS.md"
    elif [[ -e "$global_agents" ]]; then
        echo "    [!] Notice: $global_agents is an existing regular file."
        echo "        Backing up to AGENTS.md.bak before replacing with symlink."
        cp -p "$global_agents" "${global_agents}.bak"
        ln -sf "$REPO_DIR/AGENTS.md" "$global_agents"
        echo "    [+] Linked: $global_agents -> $REPO_DIR/AGENTS.md"
    else
        ln -s "$REPO_DIR/AGENTS.md" "$global_agents"
        echo "    [+] Linked: $global_agents -> $REPO_DIR/AGENTS.md"
    fi

    mkdir -p "$zed_skills_dir"
    if [[ -d "$REPO_DIR/skills" ]]; then
        for skill in "$REPO_DIR/skills/"*; do
            if [[ -d "$skill" ]]; then
                local skill_name
                skill_name="$(basename "$skill")"
                local dest_skill="$zed_skills_dir/$skill_name"

                if [[ -L "$dest_skill" ]]; then
                    ln -sfn "$skill" "$dest_skill"
                    echo "    [+] Refreshed skill: $dest_skill -> $skill"
                elif [[ -e "$dest_skill" ]]; then
                    echo "    [!] Notice: $dest_skill is a local directory (left untouched)."
                else
                    ln -s "$skill" "$dest_skill"
                    echo "    [+] Linked skill: $dest_skill -> $skill"
                fi
            fi
        done
    fi

    if [[ -d "$REPO_DIR/lib" ]]; then
        local user_lib_dir="${HOME}/.local/lib"
        mkdir -p "$user_lib_dir"
        ln -sfn "$REPO_DIR/lib" "$user_lib_dir/dev-bootstrap"
        echo "    [+] Linked shared library: $user_lib_dir/dev-bootstrap -> $REPO_DIR/lib"
    fi

    # Check for client-remote architecture warning
    if grep -qi microsoft /proc/version 2>/dev/null || [[ -n "${SSH_CONNECTION:-}" ]]; then
        echo ""
        echo "===================================================================="
        echo " [NOTICE] Remote / Client Architecture Detected"
        echo "===================================================================="
        echo " If running Zed as a Windows client connecting to this Linux host,"
        echo " the Windows client reads global configuration from:"
        echo "   - %APPDATA%\\Zed\\AGENTS.md"
        echo "   - %USERPROFILE%\\.agents\\skills\\"
        echo ""
        echo " Global Linux links (~/.config/zed) will not be visible to the client."
        echo " To enable these standards for your remote workspace, run:"
        echo "   $(basename "$0") --project <path-to-workspace>"
        echo "===================================================================="
    fi

    echo "[+] Global installation complete."
}

# Main CLI dispatch
if [[ $# -eq 0 ]]; then
    # Default behavior: if inside a git/project repo, link project; otherwise display help
    usage
    exit 0
fi

case "$1" in
    -p|--project)
        target="${2:-.}"
        link_project "$target"
        ;;
    -c|--clean|--unlink)
        target="${2:-.}"
        clean_project "$target"
        ;;
    -a|--all|-g|--global)
        link_global
        ;;
    -l|--lib-only|--headless)
        link_lib_only
        ;;
    -h|--help)
        usage
        ;;
    *)
        if [[ -d "$1" ]]; then
            link_project "$1"
        else
            echo "[-] Error: Unknown option or directory '$1'." >&2
            echo "" >&2
            usage >&2
            exit 1
        fi
        ;;
esac
