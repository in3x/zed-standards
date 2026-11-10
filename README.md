# Zed Standards & Developer Platform Library

A centralized repository serving two complementary purposes:
1. **AI Agent Standards & Skills**: Personal engineering standards, architectural axioms, and modular agent skills for use across projects in the Zed editor.
2. **Shared Developer Platform Library (`lib/`)**: Reusable POSIX/Bash operational primitives (platform detection, deterministic site selection, safe file deployment, Diceware secrets, and healthcheck telemetry) for administrative scripts across all repositories.

## Repository Contents

```text
zed-standards/
├── AGENTS.md                  # Personal engineering standards & architectural axioms
├── install.sh                 # Linker script for project workspaces and global environments
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
│   └── lib-telemetry.sh       # Healthchecks.io & NTFY push telemetry helpers
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

2. **Onboard Any Project Workspace** (executed in each cloned project):
   ```bash
   cd ~/Projects/my-app
   ~/Projects/zed-standards/install.sh --project .
   ```
   This links `.agents/skills/*` and `AGENTS.md` and keeps working copies clean via `.git/info/exclude` or `.gitignore`.
   *(To unlink: `~/Projects/zed-standards/install.sh --clean .`)*

---

### Topology 3: Three-Tier Hybrid Target Echo (Windows Client → Dev Host → Target Node)
*Dev on Ubuntu/WSL (Window 1), Test & Debug on Red Hat with SELinux (Window 2).*

When developing on a Debian/Ubuntu dev host (Tier 2) but targeting deployment and debugging on a Red Hat/Rocky/CentOS host (Tier 3) with SELinux enforcement:

```text
[ Windows Client (Desktop GUI) ]
       ├── Window 1 (SSH / WSL to Dev Host: Ubuntu)  -> Code authoring & jj VCS
       └── Window 2 (SSH to Target Node: Red Hat)     -> Native SELinux & daemon debugging
                    │
   Direct Peer Sync (sub-second over LAN/SSH, ZERO GitHub round-tripping)
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
2. **Direct Peer Sync (Bypass GitHub Round-Trips)**:
   Sync code directly between your Dev Host and Target Node in milliseconds without pushing experimental commits to GitHub:
   ```bash
   # From Dev Host (WSL/Ubuntu):
   rsync -avz --exclude='.git' --exclude='.jj' ~/Projects/my-app/ rhel-target:~/Projects/my-app/
   # Or via peer jj/git push:
   jj git push --remote rhel-target
   ```
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
