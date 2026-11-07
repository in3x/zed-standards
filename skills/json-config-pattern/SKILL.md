---
name: json-config-pattern
description: Standards and techniques for managing JSON configuration files, upstream templates, deep merging, schema validation, and two-stage lifecycle operations in Bash and Python.
---

# JSON Configuration Pattern

## 1. Directory & File Placement
Follow the two-stage lifecycle layout:
```text
project-root/
├── conf/
│   └── app.json               # Canonical upstream template with defaults
└── site-conf/
    ├── site-a/
    │   └── app.json           # Site-specific values (non-secret)
    └── site-b/
        └── app.json
```

## 2. Formatting & Syntax Standards
- **Formatting**: 2 spaces per indentation level; final newline at end of file.
- **Key Sorting**: Keep keys grouped logically or alphabetically sorted for clean version-control diffs.
- **Strict Compliance**: Standard JSON does not permit comments or trailing commas. For comments, prefer a dedicated `_comment` or `description` property on top-level objects if the consuming application allows unknown keys.

## 3. Deep-Merging Upstream Templates with Site Profiles
When merging upstream templates (`conf/`) into site profiles (`site-conf/<site>/`):
- **Rule**: Upstream provides new default keys. Site profiles override default values. Existing site customizations must never be wiped out.

### Bash Merge Pattern (`jq`)
Use `jq` recursive merge (`*`), placing the site profile on the right so its customizations take precedence over new template keys:

```bash
merge_json_profile() {
    local template="$1"
    local site_config="$2"
    local output="$3"

    if [[ ! -f "$site_config" ]]; then
        # Initial run: copy template directly
        cp "$template" "$site_config"
        echo "[+] Initialized: $site_config from template."
        return 0
    fi

    # Subsequent run: deep-merge template defaults with site overrides
    jq -s '.[0] * .[1]' "$template" "$site_config" > "$output"
    echo "[+] Merged template defaults into: $output"
}
```

### Python Merge Pattern
```python
import json
from pathlib import Path
from typing import Any

def deep_merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    """Recursively merges override into base without mutating inputs."""
    merged = base.copy()
    for key, value in override.items():
        if key in merged and isinstance(merged[key], dict) and isinstance(value, dict):
            merged[key] = deep_merge(merged[key], value)
        else:
            merged[key] = value
    return merged

def update_site_json(template_path: Path, site_config_path: Path) -> None:
    if not site_config_path.exists():
        site_config_path.parent.mkdir(parents=True, exist_ok=True)
        site_config_path.write_text(template_path.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"[+] Initialized {site_config_path} from {template_path}")
        return

    with open(template_path, "r", encoding="utf-8") as f:
        template_data = json.load(f)
    with open(site_config_path, "r", encoding="utf-8") as f:
        site_data = json.load(f)

    merged = deep_merge(template_data, site_data)

    formatted = json.dumps(merged, indent=2, ensure_ascii=False) + "\n"
    site_config_path.write_text(formatted, encoding="utf-8")
    print(f"[+] Updated {site_config_path} with new template defaults.")
```

## 4. Syntax Validation
- **Bash**:
  ```bash
  jq empty path/to/config.json || { echo "[-] Invalid JSON in config"; exit 1; }
  ```
- **Python**:
  ```bash
  python3 -m json.tool path/to/config.json > /dev/null
  ```
