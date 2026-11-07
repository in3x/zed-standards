---
name: toml-config-pattern
description: Standards and techniques for managing TOML configuration files, section layouts, table merging, comment preservation, and two-stage lifecycle operations in Bash and Python.
---

# TOML Configuration Pattern

## 1. Directory & File Placement
```text
project-root/
├── conf/
│   └── app.toml               # Canonical upstream template with defaults & table structures
└── site-conf/
    ├── site-a/
    │   └── app.toml           # Site-specific values
    └── site-b/
        └── app.toml
```

## 2. Formatting & Syntax Standards
- **Tables & Headers**: Place top-level simple keys before table definitions `[section]`.
- **String Types**:
  - Double quotes `"value"` for strings requiring escape characters.
  - Single quotes `'raw\path'` for literal strings (e.g., regex patterns, paths).
  - Triple quotes `"""..."""` for multiline descriptions.
- **Section Ordering**: Keep logically related tables contiguous. Order arrays of tables `[[item]]` cleanly at the end or in dedicated sections.

## 3. Reading and Writing in Python
- **Reading (Python 3.11+ Standard Library)**:
  ```python
  import tomllib

  with open("conf/app.toml", "rb") as f:
      config = tomllib.load(f)
  ```
- **Round-Trip Editing with Comment Preservation (`tomlkit`)**:
  When merging templates, use `tomlkit` to preserve comments and table ordering:
  ```python
  from pathlib import Path
  import tomlkit

  def update_site_toml(template_path: Path, site_config_path: Path) -> None:
      if not site_config_path.exists():
          site_config_path.parent.mkdir(parents=True, exist_ok=True)
          site_config_path.write_text(template_path.read_text(encoding="utf-8"), encoding="utf-8")
          print(f"[+] Initialized {site_config_path}")
          return

      doc_template = tomlkit.parse(template_path.read_text(encoding="utf-8"))
      doc_site = tomlkit.parse(site_config_path.read_text(encoding="utf-8"))

      # Insert missing keys/sections from template into site profile
      for key, val in doc_template.items():
          if key not in doc_site:
              doc_site.append(key, val)

      site_config_path.write_text(tomlkit.dumps(doc_site), encoding="utf-8")
      print(f"[+] Updated {site_config_path} with new upstream tables/keys.")
  ```

## 4. Merging in Bash
- **Using `yq`**:
  ```bash
  yq -p toml -o toml eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' conf/app.toml site-conf/site-a/app.toml > site-conf/site-a/app.toml.tmp
  mv site-conf/site-a/app.toml.tmp site-conf/site-a/app.toml
  ```

## 5. Syntax Validation
- **Python stdlib check**:
  ```bash
  python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' path/to/config.toml
  ```
