---
name: package-scaffolding
description: Instructions for scaffolding, structuring, and deploying packages, daemons, and projects according to standard conventions.
---

# Package Scaffolding Standards

When setting up or standardizing a repository, apply the following structure:

```text
project-root/
├── README.md
├── scripts/               # Application runtime scripts (workers, daemons, cron jobs)
├── admin/                 # Management scripts (site-profile.sh, deploy.sh, upgrade.sh)
├── conf/                  # Canonical upstream configuration templates and defaults
├── site-conf/             # Concrete site profiles (containing real configs for each environment)
│   ├── <site-a>/
│   └── <site-b>/
├── units/                 # Systemd service and timer units (if applicable)
└── docs/                  # Architecture notes and operational guides
```

## Scaffolding & Installation Rules:

1. **Target Hierarchy (Root vs. User Mode)**:
   Explicitly display the detected target paths before performing changes:

   | Role | Root / System Mode | User Mode |
   | :--- | :--- | :--- |
   | **Executables** | `/opt/<project>/bin` (or `/usr/local/bin` if already present) | `~/.local/bin/` |
   | **Configuration** | `/etc/<project>/` | `~/.config/<project>/` |
   | **Data / Storage** | `/var/lib/<project>/` | `~/.local/share/<project>/` |

   - **Never deploy a `scripts/` directory to `/opt/<project>/`.** All executables in production live in `bin/`.

2. **Respectful `~/.bashrc.d` Provisioning**:
   If the installed `bin` directory is not in `$PATH`:
   - Bootstrap `~/.bashrc.d/` if missing.
   - **Never modify `~/.bashrc` silently.** If `~/.bashrc` lacks the `~/.bashrc.d/` loader:
     - Show the exact snippet to be added.
     - Explain why (modular drop-ins) and how it benefits them (keeps `~/.bashrc` clean forever).
     - Require explicit user confirmation `[y/N]`.
     - If declined, print the manual PATH command and leave `~/.bashrc` completely untouched.
   - Drop a clean `~/.bashrc.d/<project>.bash` snippet into `~/.bashrc.d/`.

3. **Deterministic Site Selection**:
   - Every management tool that takes a site takes `$1` as the site name.
   - If `$1` is missing, prompt the user with a numbered list of available sites in `site-conf/`.

4. **Two-Stage Lifecycle**:
   - Stage 1 (`site-profile.sh`): Upstream `conf/` $\rightarrow$ `site-conf/<site>/`.
   - Stage 2 (`deploy.sh`): `site-conf/<site>/` $\rightarrow$ Target location (`/etc/<project>/` or `~/.config/<project>/`).
   - In both stages: Run 1 initializes new files; Run N performs a merge/update.

5. **Command Linking & CLI Reference Section**:
   - In READMEs, format all script references as inline clickable anchor links (e.g. [`admin/deploy.sh`](#admindeploysh)).
   - Always include a dedicated Command / CLI Reference section detailing options, side effects, required privileges, and examples.
