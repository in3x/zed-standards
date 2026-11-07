---
name: python-script-conventions
description: Standards for authoring operational and administrative Python scripts, CLI argument parsing, deterministic site selection menus, dynamic repo resolution, and root vs user target handling.
---

# Python Scripting Conventions

## 1. Script Categorization
- **Application / Operational Scripts** (`scripts/`):
  - Execute background tasks, workers, or scheduled cron/systemd service jobs.
  - Run unattended under service or unprivileged system accounts.
  - Fail with clear exit codes and structured logs.
- **Management / Administrative Scripts** (`admin/`):
  - Handle deployment, site profile management (`site-profile.py`), and migrations.
  - Run interactively by an administrator, supporting CLI flags and interactive fallbacks.

## 2. Naming Standards
- Format: `<app>-<function>.py` (e.g., `gitea-backup.py`, `site-profile.py`, `service-deploy.py`).
- Maintain single-purpose scope per script.

## 3. Interpreter, Shebang & Dependencies (PEP 723)
- Use standard Python 3 shebang:
  ```python
  #!/usr/bin/env python3
  ```
- **Self-Contained Dependency Declarations**: When third-party packages are required (e.g., `pyyaml`, `requests`), use PEP 723 inline script metadata runnable via `uv run` or `pipx`:
  ```python
  # /// script
  # requires-python = ">=3.11"
  # dependencies = [
  #     "pyyaml>=6.0",
  #     "rich>=13.0",
  # ]
  # ///
  ```
- Prefer standard library modules (`pathlib`, `argparse`, `sys`, `os`, `shutil`, `json`, `tomllib`) whenever feasible to minimize bootstrapping overhead.

## 4. Dynamic Repository Root
Always resolve paths dynamically from the script file location using `pathlib.Path`:
```python
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
```

## 5. Deterministic Site Selection (CLI or Menu Fallback)
Mirror the project's zero-magic standard: never deduce sites from hostnames or environment variables. Provide an explicit CLI flag or positional argument, and fall back to an interactive numbered menu:

```python
import sys
from pathlib import Path

def resolve_site(cli_site: str | None = None, repo_root: Path = REPO_ROOT) -> str:
    site_conf_dir = repo_root / "site-conf"

    # 1. Direct CLI argument provided
    if cli_site:
        target = site_conf_dir / cli_site
        if not target.is_dir():
            print(f"[-] Error: Site profile 'site-conf/{cli_site}' does not exist.", file=sys.stderr)
            sys.exit(1)
        return cli_site

    # 2. Collect available site profiles
    if not site_conf_dir.is_dir():
        print(f"[-] Error: Directory 'site-conf/' not found at {site_conf_dir}.", file=sys.stderr)
        sys.exit(1)

    sites = sorted([d.name for d in site_conf_dir.iterdir() if d.is_dir()])
    if not sites:
        print("[-] Error: No site profiles found in site-conf/.", file=sys.stderr)
        sys.exit(1)

    # 3. Interactive menu fallback
    if not sys.stdin.isatty():
        print("[-] Error: Site argument required in non-interactive environment.", file=sys.stderr)
        sys.exit(1)

    print("Select a site profile:", file=sys.stderr)
    for idx, site in enumerate(sites, start=1):
        print(f"  {idx}) {site}", file=sys.stderr)

    while True:
        try:
            choice = input(f"Selection [1-{len(sites)}]: ").strip()
            if not choice:
                continue
            index = int(choice)
            if 1 <= index <= len(sites):
                return sites[index - 1]
        except (ValueError, EOFError, KeyboardInterrupt):
            pass
        print("[-] Invalid selection. Please choose a valid number.", file=sys.stderr)
        sys.exit(1)
```

## 6. Installation Targets: Root vs. User Mode
Detect privileges and resolve filesystem destinations explicitly:

```python
import os
from pathlib import Path

def get_install_targets(project_name: str) -> dict[str, Path]:
    is_root = (os.geteuid() == 0) if hasattr(os, "geteuid") else False

    if is_root:
        return {
            "mode": "system",
            "bin": Path(f"/opt/{project_name}/bin"),
            "conf": Path(f"/etc/{project_name}"),
            "data": Path(f"/var/lib/{project_name}"),
        }
    else:
        home = Path.home()
        return {
            "mode": "user",
            "bin": home / ".local" / "bin",
            "conf": home / ".config" / project_name,
            "data": home / ".local" / "share" / project_name,
        }
```

## 7. Transparent Dotfile & `~/.bashrc.d` Wiring
Follow the same respectful dotfile guidelines when configuring PATH:
- Never edit `~/.bashrc` silently.
- Prompt with clear explanation (what, why, benefits) before appending the `~/.bashrc.d` loader.
- Drop application PATH variables into `~/.bashrc.d/<project>.bash`.

## 8. CLI Structure & Main Entry Point
Use `argparse` and structured `main()`:

```python
import argparse
import sys

def main() -> int:
    parser = argparse.ArgumentParser(description="Operational tool description.")
    parser.add_argument("site", nargs="?", help="Site profile name from site-conf/")
    parser.add_argument("--dry-run", action="store_true", help="Simulate actions without writing")
    args = parser.parse_args()

    site = resolve_site(args.site)
    print(f"[+] Active site profile: {site}")
    # Perform work here...
    return 0

if __name__ == "__main__":
    sys.exit(main())
```
