# Zed Standards & Developer Platform Library

A centralized repository serving two complementary purposes:
1. **AI Agent Standards & Skills**: Personal engineering standards, architectural axioms, and modular agent skills for use across projects in the Zed editor.
2. **Shared Developer Platform Library (`lib/`)**: Reusable POSIX/Bash operational primitives (platform detection, deterministic site selection, safe file deployment, Diceware secrets, and healthcheck telemetry) for administrative scripts across all repositories.

## Repository Contents

```text
zed-standards/
├── AGENTS.md                  # Personal engineering standards & architectural axioms
├── install.sh                 # Linker script (Bash implementation, preserved for A/B testing)
├── install.py                 # Linker script (Strongly-typed Python implementation)
├── admin/
│   ├── jj-install.sh          # Jujutsu (jj) installer & auto-upgrader
│   └── host-bootstrap.sh      # Host bootstrap script (installs jj, ~/.bashrc.d, dev-bootstrap)
├── lib/                       # Shared platform library (symlinked to ~/.local/lib/dev-bootstrap)
│   ├── lib-common.sh          # Loader for all platform primitives
│   ├── lib-platform.sh        # OS & CPU architecture detection (amd64, arm64, musl targets)
│   ├── lib-site.sh            # Deterministic site resolution (CLI argument or interactive menu)
│   ├── lib-deploy.sh          # Safe interactive file deployment (diff inspection, chmod/chown)
│   ├── lib-secret.sh          # Diceware passphrase generator & proof-of-capture ceremony
│   ├── lib-cidata.sh          # NoCloud Cloud-Init ISO generation helper
│   ├── lib-telemetry.sh       # Healthchecks.io & NTFY push telemetry helpers
│   └── site_profile.py        # Universal Stage 1 site profile manager & INI merge engine
├── docs/
│   ├── design.md                      # Client/remote architecture and distribution design notes
│   └── remote-development-workflow.md # Peer Jujutsu sync & direct SSH deployment workflow
├── skills/
│   ├── package-scaffolding/       # Standard directory layout, root vs. user mode targets
│   ├── site-conf-pattern/         # Site-specific profile isolation & deterministic resolution
│   ├── script-conventions/        # Bash script naming, templates, ~/.bashrc.d provisioning
│   ├── python-script-conventions/ # Python script structure, PEP 723, CLI/menu site selection
│   ├── json-config-pattern/       # JSON configuration templates, jq/Python deep merges
│   ├── yaml-config-pattern/       # YAML templates, comment preservation, yq/ruamel.yaml
│   ├── toml-config-pattern/       # TOML configuration tables, tomlkit/tomllib patterns
│   └── soml-config-pattern/       # SOML (Sindre's Objectively Marvelous Language) conventions
└── README.md
```

## Architectural Highlights

1. **Jujutsu (`jj`) First**: Default version control tool for all repositories.
2. **Deterministic Site Selection**: No guesswork or shared-disk symlinks; strictly CLI argument `$1` with an interactive numbered menu fallback.
3. **Dual-Mode Target Hierarchy**:
   - **Root/System**: Executables to `/opt/<project>/bin`, configs to `/etc/<project>/`.
   - **User Mode**: Executables to `~/.local/bin`, configs to `~/.config/<project>/`.
4. **Transparent Dotfile Management**: Never modify `~/.bashrc` silently. Always explain what, why, and how it benefits the user before prompting for confirmation to wire up `~/.bashrc.d`.
5. **Two-Stage Config Lifecycle**: Upstream `conf/` templates (Bash env, JSON, YAML, TOML, SOML) merge non-destructively into `site-conf/<site>/` via `site-profile` tools, which in turn deploy to system targets via deploy tools.

## Operational Topologies & Workflows

This repository supports three distinct deployment configurations:

### Topology 1: Pure Local Workstation (Native Desktop Zed)
*Single machine running both the Zed GUI and local development (Linux / macOS).*

```bash
# Full local install: links global skills, AGENTS.md, and platform library (~/.local/lib/dev-bootstrap)
./install.sh --all
```
*(See [`install.sh` CLI Reference](#installsh) for all flags and options)*

---

### Topology 2: Two-Tier Client-Remote (Windows Client → Remote Dev Host)
*Zed GUI runs on a Windows workstation; code authoring, terminals, and VCS run inside a remote Linux VM or WSL.*

Because the Windows Zed client does not read global paths on the remote Linux host (`~/.config/zed`), standards are linked directly into each project workspace root on the remote machine:

1. **Bootstrap the Dev Host** (executed once locally on the remote Linux VM / WSL):
   ```bash
   mkdir -p ~/Projects
   git clone git@github.com:in3x/zed-standards.git ~/Projects/zed-standards
   bash ~/Projects/zed-standards/admin/host-bootstrap.sh
   source ~/.bashrc
   ```
   *(See [`admin/host-bootstrap.sh` Reference](#adminhost-bootstrapsh) for arguments)*

2. **Onboard Any Project Workspace** (executed in each cloned project):
   ```bash
   cd ~/Projects/my-app
   ~/Projects/zed-standards/install.sh --project .
   ```
   This links `.agents/skills/*` and `AGENTS.md` and keeps working copies clean via `.git/info/exclude` or `.gitignore`.
   *(To unlink: `~/Projects/zed-standards/install.sh --clean .` — see [`install.sh` Reference](#installsh))*

---

### Topology 3: Three-Tier Hybrid Target Echo (Windows Client → Dev Host → Target Node)
*Dev on Ubuntu/WSL (Window 1), Test & Debug on Red Hat with SELinux (Window 2).*

When developing on a Debian/Ubuntu dev host (Tier 2) but targeting deployment and debugging on a Red Hat/Rocky/CentOS host (Tier 3) with SELinux enforcement:

```text
[ Windows Client (Desktop GUI) ]
       ├── Window 1 (SSH / WSL to Dev Host: Ubuntu)  -> Code authoring & jj VCS
       └── Window 2 (SSH to Target Node: Red Hat)     -> Native SELinux & daemon debugging
                    │
   Bidirectional Peer Sync via Jujutsu (sub-second over LAN/SSH, ZERO GitHub round-tripping)
                    ▼
[ Target Node (Red Hat / Appliance) ]
   • Provisioned via: bash ~/Projects/zed-standards/admin/host-bootstrap.sh --lib-only
   • Linked via:      ~/Projects/zed-standards/install.sh --project .
```

1. **Provision the Target Node**:
   Run the headless bootstrap on the Red Hat machine to install `jj` and `~/.local/lib/dev-bootstrap`:
   ```bash
   bash ~/Projects/zed-standards/admin/host-bootstrap.sh --lib-only
   ```
   *(See [`admin/host-bootstrap.sh` Reference](#adminhost-bootstrapsh))*

2. **Bidirectional Peer Sync via Jujutsu (Dominant Method - Zero GitHub Round-Trips)**:
   Add the Target Node as an SSH remote on your Dev Host to synchronize working revisions in milliseconds without polluting GitHub with experimental commits:
   ```bash
   # On Dev Host: register the Target Node as an SSH peer remote
   jj git remote add rhel-target ssh://rhel-target/home/user/Projects/my-app

   # Push working copy revisions directly to Red Hat:
   jj git push --remote rhel-target
   ```
   **Bidirectional Sync**: If you or the agent in Window 2 make fixes, adjust configuration files, or compile SELinux policies directly on the Red Hat node, pull them straight back into your Dev Host:
   ```bash
   # On Dev Host: synchronize changes made on Red Hat back into your working copy
   jj git fetch --remote rhel-target
   ```
   *(Fallback for uninitialized targets without git/jj: `rsync -avz --exclude='.git' --exclude='.jj' ~/Projects/my-app/ rhel-target:~/Projects/my-app/`)*

3. **Dual-Window Debugging**:
   - **Window 1 (Dev Host)**: The Zed agent authors features, updates configuration templates, and tracks changes in `jj`.
   - **Window 2 (Target Node)**: A second Zed window connects directly to the Red Hat node. The agent operates *natively* on Red Hat with direct access to inspect SELinux denials (`ausearch -m avc -ts recent`), compile policy packages (`audit2allow`), and debug systemd daemons (`journalctl -u my-daemon -f`).

---

### Headless Server & CI/CD Pipelines (Audience B)
On production servers, test benches, or CI/CD runners where AI editor skills are not needed:

```bash
# Install only the shared platform library (~/.local/lib/dev-bootstrap):
./install.sh --lib-only

# Or provision the whole host in headless mode:
bash ./admin/host-bootstrap.sh --lib-only
```

---

## Command & CLI Reference

Comprehensive documentation for all executable tools provided by this repository.

### `install.sh`
The primary linker and environment provisioning entry point. Used for onboarding project workspaces, installing global standards, or deploying the shared platform library.

**Usage:**
```bash
./install.sh [OPTIONS] [PROJECT_PATH]
```

**Options & Flags:**
| Option | Profile | Description |
| :--- | :--- | :--- |
| `-p, --project <path>` | **Audience A** | Links `.agents/skills/*` and `AGENTS.md` into the specified project workspace. Registers `.agents/` and `AGENTS.md` in `.git/info/exclude` (or `.gitignore` for Jujutsu). Defaults to `.` if `<path>` is omitted. |
| `-a, --all, -g, --global` | **Audience A** | Full host install: links global skills to `~/.agents/skills`, `AGENTS.md` to `~/.config/zed`, and the shared platform library to `~/.local/lib/dev-bootstrap`. |
| `-l, --lib-only, --headless` | **Audience B** | Headless server install: links **only** the shared platform library to `~/.local/lib/dev-bootstrap`. Omits editor skills and AI prompts entirely. |
| `-c, --clean <path>` | Maintenance | Safely unlinks `zed-standards` symlinks (`.agents/skills/*` and `AGENTS.md`) from a project workspace while strictly preserving any project-authored files. Defaults to `.`. |
| `-h, --help` | General | Displays usage help and examples. |

**Examples:**
```bash
# Onboard current repository:
./install.sh --project .

# Onboard specific project:
./install.sh --project ~/Projects/my-app

# Headless server library setup:
./install.sh --lib-only

# Safely unlink standards from a project:
./install.sh --clean ~/Projects/my-app
```

---

### `admin/host-bootstrap.sh`
Prepares a target Linux machine (VM, remote dev server, or physical host) by installing required developer tooling and wiring environment paths. Run directly on the machine being provisioned.

**Usage:**
```bash
bash ~/Projects/zed-standards/admin/host-bootstrap.sh [OPTIONS] [JJ_OPTIONS]
```

**Options & Modes:**
| Option | Description |
| :--- | :--- |
| *(default / `--all`)* | **[Audience A]** Full interactive development host setup: installs `jj`, provisions `~/.bashrc.d` with `~/.local/bin` PATH loader, and symlinks `~/.local/lib/dev-bootstrap`. |
| `-l, --lib-only, --headless` | **[Audience B]** Headless production server setup: installs `jj` and the shared platform library (`~/.local/lib/dev-bootstrap`), skipping interactive editor conveniences. |
| `-h, --help` | Displays usage instructions and forwarded options. |

**Forwarded Jujutsu (`jj-install.sh`) Options:**
Any of these flags are passed directly through to the Jujutsu installer:
- `-v, --version <TAG>`: Install a specific Jujutsu version (e.g. `v0.47.1`).
- `-f, --force`: Force reinstall or update even if the current version matches.
- `--user`: Install to `~/.local/bin` (default for non-root users).
- `--system`: Install system-wide to `/usr/local/bin` (requires root/sudo).
- `-d, --dir <PATH>`: Custom destination directory for the `jj` binary.

**Examples:**
```bash
# Standard dev host setup:
bash ~/Projects/zed-standards/admin/host-bootstrap.sh

# Headless node setup:
bash ~/Projects/zed-standards/admin/host-bootstrap.sh --lib-only

# Force update Jujutsu to latest release:
bash ~/Projects/zed-standards/admin/host-bootstrap.sh --force
```

---

### `admin/jj-install.sh`
A single-purpose installer and auto-upgrader for Jujutsu (`jj`). Queries the GitHub API for releases, detects CPU architecture, and checks installed binary versions before downloading.

**Usage:**
```bash
./admin/jj-install.sh [OPTIONS]
```

**Options & Flags:**
| Option | Description |
| :--- | :--- |
| `-v, --version <TAG>` | Install a specific version tag (e.g. `v0.47.1` or `0.47.1`). |
| `-f, --force` | Force re-download and reinstall even if the installed version is current. |
| `--user` | Target `~/.local/bin` (default for standard users). |
| `--system` | Target `/usr/local/bin` (default for root). |
| `-d, --dir <PATH>` | Explicit custom destination directory. |
| `-h, --help` | Displays usage summary. |

**Auto-Upgrade Behavior:**
If `jj` is already present, `jj-install.sh` extracts the current version (e.g. `0.46.0`), compares it against the latest release tag (e.g. `0.47.1`), and only downloads if an upgrade is available.

---

### `lib/` (Platform Library Modules)
Shared shell modules symlinked into `~/.local/lib/dev-bootstrap` and available to scripts across all repositories.

| Module | Purpose | Key Functions Provided |
| :--- | :--- | :--- |
| **`lib-common.sh`** | Universal loader | Sources all `lib-*.sh` modules in a single line: `source ~/.local/lib/dev-bootstrap/lib-common.sh`. |
| **`lib-platform.sh`** | Platform detection | `detect_os` (linux/darwin), `detect_arch` (x86_64/aarch64), `detect_arch_alias` (amd64/arm64), `detect_musl_target`. |
| **`lib-site.sh`** | Site resolution | `resolve_site`, `resolve_or_create_site` (validates `$1` or displays sorted interactive menu). |
| **`lib-deploy.sh`** | Safe deployment | `require_root`, `install_file_safely` (`cmp -s` check, diff prompt `[y/d/n/c]`, permissions). |
| **`lib-secret.sh`** | Secrets & Passphrases | `generate_diceware_passphrase` (~75 bits entropy), `proof_of_capture_ceremony`. (Self-contained for host or Cloud-Init injection). |
| **`lib-cidata.sh`** | Cloud-Init ISOs | `build_nocloud_iso` (assembles NoCloud cidata ISO images using `genisoimage`, `mkisofs`, or `xorriso`). |
| **`lib-telemetry.sh`** | Telemetry & Alerts | `ping_hc` (Healthchecks.io), `send_ntfy` (ntfy.sh push alerts), `failure_handler` (ERR trap). |
