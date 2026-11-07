---
name: yaml-config-pattern
description: Standards and techniques for managing YAML configuration files, comment preservation, two-stage merges, linting, and safe parsing in Bash and Python.
---

# YAML Configuration Pattern

## 1. Directory & File Placement
```text
project-root/
├── conf/
│   └── app.yaml               # Canonical upstream template with defaults & comments
└── site-conf/
    ├── site-a/
    │   └── app.yaml           # Site-specific customizations
    └── site-b/
        └── app.yaml
```

## 2. Formatting & Syntax Standards
- **Indentation**: Exactly 2 spaces per indentation level. Never use tabs.
- **Explicit String Quoting**: Quote boolean-like strings, country codes, or version numbers to prevent unexpected type coercion:
  ```yaml
  country: "NO"           # Avoid unquoted NO (coerces to false in YAML 1.1)
  feature_enabled: true  # Explicit boolean
  version: "1.0"         # Avoid float coercion
  ```
- **List Style**: Consistently indent list hyphens under parent keys:
  ```yaml
  servers:
    - host: site-a.internal
      port: 8080
  ```

## 3. Merging with Comment Preservation
Preserving inline documentation and comments is critical when updating configuration profiles.

### Bash Merge Pattern (`yq`)
Using `yq` (mikefarah/yq), merge the template and site profile while preserving structure and comments:

```bash
merge_yaml_profile() {
    local template="$1"
    local site_config="$2"
    local output="$3"

    if [[ ! -f "$site_config" ]]; then
        cp "$template" "$site_config"
        echo "[+] Initialized: $site_config from template."
        return 0
    fi

    # Merge: site-config overrides template defaults
    yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "$template" "$site_config" > "$output"
    echo "[+] Merged YAML into: $output"
}
```

### Python Merge Pattern (`ruamel.yaml` for Round-Trip Preservation)
Use `ruamel.yaml` when round-tripping to preserve comments:

```python
from pathlib import Path
from ruamel.yaml import YAML

def update_site_yaml(template_path: Path, site_config_path: Path) -> None:
    yaml = YAML()
    yaml.preserve_quotes = True
    yaml.indent(mapping=2, sequence=4, offset=2)

    if not site_config_path.exists():
        site_config_path.parent.mkdir(parents=True, exist_ok=True)
        site_config_path.write_text(template_path.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"[+] Initialized {site_config_path}")
        return

    with open(template_path, "r", encoding="utf-8") as f:
        template_data = yaml.load(f)
    with open(site_config_path, "r", encoding="utf-8") as f:
        site_data = yaml.load(f)

    # Add missing keys from template into site_data
    for key, val in template_data.items():
        if key not in site_data:
            site_data[key] = val

    with open(site_config_path, "w", encoding="utf-8") as f:
        yaml.dump(site_data, f)
    print(f"[+] Updated {site_config_path} with new upstream keys.")
```

## 4. Syntax Validation
- **Bash with Python one-liner**:
  ```bash
  python3 -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1]))' path/to/config.yaml
  ```
- **Bash with yamllint**:
  ```bash
  yamllint -d "{extends: relaxed, rules: {line-length: disable}}" path/to/config.yaml
  ```
