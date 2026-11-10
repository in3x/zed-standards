# Personal Engineering & Architecture Standards

## General Principles
- Fix problems at the root cause; avoid surface-level patches.
- Keep changes minimal, surgical, and idiomatic to the project.
- Do not commit changes or modify remote state unless explicitly instructed.
- Prefer low-friction, deterministic solutions over clever magic.

## Version Control (Jujutsu)
- Use Jujutsu (`jj`) as the default VCS tool rather than raw `git`.
- Always pass `--no-pager` (or set `PAGER=cat`) for read-only Jujutsu commands (e.g. `jj --no-pager status`, `jj --no-pager log`, `jj --no-pager diff`) so interactive pagers do not hang.
- Use `jj --no-pager status`, `jj --no-pager diff`, and `jj --no-pager log` for inspection.
- Describe working copy revisions with clear, concise messages in the imperative mood.
- **Workflow Shorthand**:

  - When instructed to **`"mark it"`** or **`"record it"`**:
    1. Inspect changes: `jj status` and `jj diff --stat`
    2. Describe the active change: `jj describe -m "<message>"`
    3. Seal the revision and open a fresh working copy: `jj new`
    4. Advance tracking bookmark to the sealed revision: `jj bookmark set <branch> -r @-` (defaulting to `main`)

  - When instructed to **`"ship it"`**, **`"land it"`**, or **`"bookmark and push"`**:
    1. Inspect changes: `jj status` and `jj diff --stat`
    2. Describe the active change: `jj describe -m "<message>"`
    3. Seal the revision and open a fresh working copy: `jj new`
    4. Advance tracking bookmark to the sealed revision: `jj bookmark set <branch> -r @-` (defaulting to `main`)
    5. Push updated bookmark & commits to remote: `jj git push --remote origin --bookmark <branch>` (defaulting to `main`)

## Script & Tooling Architecture
- **Single-Purpose Scripts**: Keep one script to one function (or very closely related functions).
- **Separation of Concerns**:
  1. **Application / Runtime Scripts**: Executables that perform the operational work of the package (`scripts/`).
  2. **Management / Admin Scripts**: Tools for deployment, site profile management, and host upgrades (`admin/`, e.g., `site-profile.sh`, `site-profile.py`).
- **Script Naming**: Strictly `<app>-<function>.sh` or `<app>-<function>.py`.
- **Dynamic Repository Root**:
  - Bash:
    ```bash
    REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    ```
  - Python:
    ```python
    from pathlib import Path
    REPO_ROOT = Path(__file__).resolve().parent.parent
    ```
- **Interpreter & Safety Standards**:
  - Bash: Always start with `set -euo pipefail`.
  - Python: Use `#!/usr/bin/env python3`. For scripts with third-party dependencies, declare inline metadata via PEP 723 (`# /// script`). Prefer standard library when feasible.

## Deterministic Site Selection (CLI or Menu)
- **Zero Magic**: Do not use environment variables, local state files, or hostname guessing to deduce sites.
- **Strict Rule**:
  1. If site argument is passed on CLI (`$1`), validate and use it directly.
  2. If omitted, present an interactive numbered menu listing profiles from `site-conf/`.

## Installation Targets: Root vs. User Mode
Always explicitly display the chosen target paths to the user.

- **System Mode (Run as Root / Sudo)**:
  - Executables: `/opt/<project>/bin` (or `/usr/local/bin` only if already present there).
  - Configuration: `/etc/<project>/`.
  - Data: `/var/lib/<project>/`.
  - Note: Never deploy a `scripts/` directory to `/opt/<project>/`. All executables go into `bin/`.

- **User Mode (Run as Regular User)**:
  - Executables: `~/.local/bin/`.
  - Configuration: `~/.config/<project>/`.
  - Data: `~/.local/share/<project>/`.

## Low-Friction PATH & Environment Setup (`~/.bashrc.d`)
- **Never touch a user's `~/.bashrc` invisibly or unprompted**:
  - If `~/.bashrc` does not source `~/.bashrc.d/`, **ask for explicit confirmation [y/N] before modifying `~/.bashrc`**.
  - Clearly explain:
    1. **What** will be appended (display the exact code snippet).
    2. **Why** it is needed (enables modular drop-in scripts without editing `~/.bashrc`).
    3. **How it benefits them** (future tools/packages install their PATH and env vars cleanly into isolated `~/.bashrc.d/<app>.bash` files without touching core dotfiles).
  - If declined, respect their choice and display the manual export command.
  - Once approved, place `~/.bashrc.d/<project>.bash` into `~/.bashrc.d/`.

## Configuration & Two-Stage Merge Lifecycle
- **`conf/` owns all templates**: Stores canonical upstream configuration templates and defaults (Bash env, JSON, YAML, TOML, SOML).
- **`site-conf/` holds concrete site configs**: Under `site-conf/<site-id>/`, store actual configuration files with non-secret site values.
- **Structured Deep Merges**: Upstream changes must add new keys/defaults into site profiles without clobbering site-specific customizations.
- **Two-Stage Lifecycle**:
  - **Stage 1 (Upstream Template -> Site Profile)**: Handled by `site-profile.sh` or `site-profile.py`. Copies on first run; performs a structured deep merge on subsequent runs.
  - **Stage 2 (Site Profile -> Target Location)**: Handled by deployment scripts. Copies on first run; diffs and prompts before merging on subsequent runs.
