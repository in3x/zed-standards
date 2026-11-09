# Standards Evaluation & Implemented Changes: updates-notify

## 1. Executive Summary

`updates-notify` provides fleet-wide automated security updates, unattended upgrade hooks, and conditional reboot orchestration. 

While its operational logic was sound, the repository had several structural inconsistencies: the deployment script was located in the root directory, package manager configuration templates were scattered at the top level, unit files were duplicated across two separate directories, and scripts did not follow the `<app>-<function>.sh` naming convention.

---

## 2. Standards Compliance & Changes Implemented

| Area | Previous State | New Compliant State | Standard Reference |
| :--- | :--- | :--- | :--- |
| **Admin Script Location** | `deploy.sh` in repository root | Moved to `admin/updates-deploy.sh` | `package-scaffolding` |
| **Script Naming** | Lacked `<app>-` prefix (`conditional-reboot.sh`, etc.) | Renamed to `updates-reboot.sh`, `updates-apt-telemetry.sh`, `updates-failure-notify.sh`, `updates-telemetry-common.sh` | `script-conventions` |
| **Backward Compatibility** | Direct file paths in `/usr/local/bin/` | `updates-deploy.sh` creates symlinks in `/usr/local/bin` (e.g. `conditional-reboot.sh -> updates-reboot.sh`) to ensure existing timers and APT hooks continue running | Safe Operations |
| **Package Templates** | `apt/` and `dnf/` scattered at root | Reorganized under `conf/apt/` and `conf/dnf/` | `package-scaffolding` |
| **Duplicate Unit Definitions** | Both `units/` and `systemd/system/` existed with diverging contents | Removed duplicate/outdated `systemd/` directory; `units/` is canonical | Clean Scaffolding |
| **Shared Platform Library** | Re-implemented `install_file_safely` and inline telemetry | Sources `lib-deploy.sh` and `lib-telemetry.sh` from `~/.local/lib/dev-bootstrap` | Developer Platform Library |
| **Repository Hygiene** | `#README.md#` and `common-telemetry.sh~` committed | Deleted stray lock/backup files, added `.gitignore` | Version Control Hygiene |

---

## 3. New Repository Layout

```text
updates-notify/
├── admin/
│   └── updates-deploy.sh          # Stage 2 deployment script (run as root)
├── scripts/                       # Operational worker scripts (installed to /usr/local/bin)
│   ├── updates-reboot.sh          # Core reboot checks, process locks, and dispatch
│   ├── updates-apt-telemetry.sh   # Unattended-upgrades post-install telemetry
│   ├── updates-failure-notify.sh  # Systemd OnFailure notification dispatcher
│   └── updates-telemetry-common.sh # Shared healthchecks and ntfy alerting library
├── conf/                          # Upstream canonical configurations & package manager overrides
│   ├── 99-local.conf.example      # Node configuration template
│   ├── apt/apt.conf.d/            # Debian/Ubuntu unattended-upgrades configuration
│   └── dnf/                       # RHEL/Rocky DNF automatic configuration
└── units/                         # Systemd service and timer definitions
    ├── conditional-reboot.service
    ├── conditional-reboot.timer
    └── failure-notification@.service
```

---

## 4. Verification

- All shell scripts passed `bash -n` syntax validation.
- Internal sourcing paths updated between scripts (`updates-reboot.sh` $\rightarrow$ `updates-telemetry-common.sh`).
- Updated `README.md` with new layout tree and execution paths.
