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
│   └── zed-remote-bootstrap.sh # Remote Linux host bootstrap script (installs jj, ~/.bashrc.d)
├── lib/                       # Shared platform library (symlinked to ~/.local/lib/dev-bootstrap)
│   ├── lib-common.sh          # Loader for all platform primitives
│   ├── lib-platform.sh        # OS & CPU architecture detection (amd64, arm64, musl targets)
│   ├── lib-site.sh            # Deterministic site resolution (CLI argument or interactive menu)
│   ├── lib-deploy.sh          # Safe interactive file deployment (diff inspection, chmod/chown)
│   ├── lib-secret.sh          # Diceware passphrase generator & proof-of-capture ceremony
│   ├── lib-cidata.sh          # NoCloud Cloud-Init ISO generation helper
│   └── lib-telemetry.sh       # Healthchecks.io & NTFY push telemetry helpers
├── docs/
│   └── design.md              # Client/remote architecture and distribution design notes
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

## Usage & Installation

### Remote Linux VM / Client-Remote Architecture
When running Zed as a Windows client connecting to remote Linux VMs (or WSL), global configuration on the remote VM (`~/.config/zed`) is not read by the Windows client. Instead, link standards directly into each workspace:

```bash
# Link standards into the current repository
./install.sh --project .

# Or specify a target project path
./install.sh --project ~/Projects/my-app
```

This:
1. Links all skills into `<project>/.agents/skills/`.
2. Links `AGENTS.md` (without overwriting existing project rules).
3. Automatically adds `.agents/` and `AGENTS.md` to `.git/info/exclude` to keep working copies clean and prevent pushing personal symlinks upstream.

> **Note on Jujutsu (`jj`)**: Linking these markdown files provisions the Zed agent's skills and axioms, which mandate `jj` as the primary VCS tool. To install `jj` or upgrade an existing installation to a higher revision, run:
> ```bash
> ./admin/jj-install.sh
> ```
> This queries GitHub for the latest stable release, checks your current version, and automatically upgrades the binary if a higher version exists.

For architectural background and details, see [`docs/design.md`](docs/design.md).

### Remote Host Bootstrapping
On a new remote Linux host, VM, or container, clone the repository securely and run the bootstrap script to install Jujutsu (`jj`), configure `~/.bashrc.d`, and register the `zed-init` shell function:

```bash
mkdir -p ~/Projects
git clone git@github.com:in3x/zed-standards.git ~/Projects/zed-standards
bash ~/Projects/zed-standards/admin/zed-remote-bootstrap.sh
```

*(Alternatively, if SSH keys are not yet configured on the host, use HTTPS: `git clone https://github.com/in3x/zed-standards.git ~/Projects/zed-standards`)*

Once bootstrapped, reload your shell (`source ~/.bashrc`) and initializing any project workspace is as simple as:

```bash
cd ~/Projects/my-app
zed-init
```

### Local Global Installation
To install into local user configuration paths:

```bash
# Audience A (Full: AI skills + AGENTS.md + shared platform library)
./install.sh --all

# Audience B (Library Only: for headless servers, production nodes, or CI/CD)
./install.sh --lib-only
```

*(For headless server bootstrap without editor tools: `bash ./admin/zed-remote-bootstrap.sh --lib-only`)*
