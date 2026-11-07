# Zed Standards & Global Agent Skills

A centralized repository containing personal engineering standards, repository scaffolding rules, and modular agent skills for use across all projects in the Zed editor.

## Repository Contents

```text
zed-standards/
├── AGENTS.md                  # Global axioms symlinked to ~/.config/zed/AGENTS.md
├── install.sh                 # Bootstrap script linking AGENTS.md and skills into global paths
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

## Installation / Sync

To link or refresh this repository into your global Zed environment:
```bash
./install.sh
```
