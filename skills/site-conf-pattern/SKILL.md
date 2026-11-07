---
name: site-conf-pattern
description: Rules and architecture for managing site-specific configuration profiles, CLI/menu resolution, two-stage merge lifecycle, and site-profile scripts.
---

# Site-Conf Pattern Standard

The `site-conf/` pattern decouples generic application code from site-specific infrastructure settings (domains, hostnames, cert paths, ports) without relying on fragile guessing or shared-disk state.

## Directory Layout
```text
project-root/
├── conf/
│   └── <app>.conf           # Canonical upstream template/defaults
└── site-conf/
    ├── <site-a>/            # Concrete production config files for site A
    │   └── <app>.conf       # Tailored config ready for target location
    └── <site-b>/            # Concrete production config files for site B
        └── <app>.conf
```

## Core Principles:

### 1. Concrete Configs over Abstract Envs
- Place actual production configuration files (e.g., `app.ini`, `daemon.conf`) inside `site-conf/<site>/`.
- Avoid intermediate `.env` files unless the application itself is a pure shell script that sources them directly.

### 2. Strictly Deterministic Resolution: CLI Argument or Menu
No hostname guessing, environment variable fallbacks, or hidden state files.

1. **CLI Argument Provided (`$1`):** Validate that `site-conf/$1` exists and use it immediately (supports headless automation).
2. **CLI Argument Omitted:** Present an interactive numbered menu listing all directories in `site-conf/`.

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

### 3. Dedicated `site-profile.sh` Management Tool
A dedicated script (`admin/site-profile.sh`) manages the profile lifecycle:
- Accepts `<site-name>` as `$1` or falls back to the interactive menu.
- **Run 1 (New Profile):** Copies templates from `conf/` into `site-conf/<site>/`.
- **Run N (Existing Profile):** Performs a structured diff/merge between new upstream keys in `conf/` and the customized `site-conf/<site>/`.
