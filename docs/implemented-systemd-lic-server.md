# Standards Evaluation & Implemented Changes: systemd-lic-server

## 1. Executive Summary

`systemd-lic-server` manages the systemd service definitions, environment configurations, and SELinux policies for Cadence EDA license daemons (`lmgrd`). 

Because this repository predated `zed-standards`, all files originally sat in a flat directory at the repository root, deployment was managed via a raw `makefile` that bypassed change detection, and there was no separation between configuration templates, unit files, and administrative scripts. The repository has now been refactored into clean standard scaffolding.

---

## 2. Standards Compliance & Changes Implemented

| Area | Previous State | New Compliant State | Standard Reference |
| :--- | :--- | :--- | :--- |
| **Directory Scaffolding** | Flat root directory | Segregated into `admin/`, `conf/`, `conf/selinux/`, `site-conf/`, `units/`, `docs/` | `package-scaffolding` |
| **Deployment Engine** | Raw `makefile` without interactive safety checks | `admin/cadence-deploy.sh` using `install_file_safely` and `require_root` | `script-conventions` |
| **SELinux Policy Tooling** | Manual `sudo semodule -i` command in README | `admin/cadence-selinux.sh` helper (`--install`, `--status`, `--rebuild`) | Single-Purpose Scripts |
| **Backward Compatibility** | `make install` expected by users | `makefile` delegates `install` target to `admin/cadence-deploy.sh` | Safe Operations |
| **Two-Stage Config** | Single hardcoded `.env` at root | Template in `conf/cadence-license.env`; site overrides enabled via `site-conf/` | `site-conf-pattern` |
| **Shared Platform Library** | No shared tooling | Sources `lib-common.sh` from `~/.local/lib/dev-bootstrap` | Developer Platform Library |
| **Agent Context** | Missing `AGENTS.md` and skills | `AGENTS.md` linked, all 8 global skills active, registered in `.git/info/exclude` | Zed Agent Skills |

---

## 3. New Repository Layout

```text
systemd-lic-server/
├── admin/                         # Administrative deployment & management tools
│   ├── cadence-deploy.sh          # Stage 2 deployment: installs unit, env, and verifies daemon
│   └── cadence-selinux.sh         # Helper to inspect, install, or rebuild SELinux policy
├── conf/                          # Upstream canonical configuration templates
│   ├── cadence-license.env        # Environment variables (INSTALL_DIR, LICENSE_FILE, LOG_FILE)
│   ├── cadence-license.conf       # Systemd drop-in format equivalent
│   └── selinux/                   # SELinux policy module sources
│       ├── pw-cdslmd-port80.te    # SELinux Type Enforcement policy source
│       └── pw-cdslmd-port80.pp    # Compiled SELinux policy package
├── site-conf/                     # Concrete site profiles (git-ignored)
│   └── .gitignore
├── units/                         # Systemd unit files
│   └── cadence-license.service    # Systemd service unit for Cadence license server
├── makefile                       # Classic make targets (delegates to admin/cadence-deploy.sh)
└── README.md
```

---

## 4. Verification

- All shell scripts passed `bash -n` syntax validation.
- Makefile targets verified against updated script locations.
- `README.md` updated with new directory tree and management commands.
