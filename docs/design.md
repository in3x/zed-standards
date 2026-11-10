# Design Document: Remote Architecture & Standards Distribution

## 1. Problem Statement & Architecture Context

When using Zed in a client-remote architecture—where the **Zed GUI client runs on Windows** and development takes place on **remote Linux VMs** (via SSH, WSL, or virtual machines)—global configuration cannot follow traditional single-machine patterns.

### The Client / Remote Divide

Zed discovers instructions and agent skills through two distinct tiers:

```
[ Windows Host (Zed Client GUI) ]
  ├── %APPDATA%\Zed\AGENTS.md              <-- Global personal instructions
  └── %USERPROFILE%\.agents\skills\        <-- Global agent skills catalog
             │
             │ Remote Connection (SSH / WSL)
             ▼
[ Remote Linux VM (Development Target) ]
  ├── ~/.config/zed/AGENTS.md              <-- IGNORED by Windows Zed client
  ├── ~/.agents/skills/                    <-- IGNORED by Windows Zed client
  └── /path/to/project/ (Workspace Root)
      ├── AGENTS.md                        <-- RECOGNIZED (Project-scoped rules)
      └── .agents/skills/                  <-- RECOGNIZED (Project-scoped skills)
```

1. **Global Configuration Lives on the Client**:
   The Zed client GUI resolves global configuration (`AGENTS.md` and global skills) **locally on Windows**. It never queries `~/.config/zed` or `~/.agents/skills` on the remote Linux host.
2. **Remote Filesystem Isolation**:
   Running a naive install script on a remote Linux VM that links to `~/.config/zed` and `~/.agents/skills` results in an invisible installation: the Windows Zed client remains unaware of these standards.
3. **Cross-Boundary Symlink Infeasibility**:
   - Creating Linux symlinks on NTFS/DrvFS (e.g., `/mnt/c`) produces WSL-specific reparse points that standard Windows Win32 processes cannot resolve (*"The file cannot be accessed by the system"*).
   - Remote Linux VMs connected over network SSH have no access to the Windows host filesystem at all.

---

## 2. Core Decisions & Technical Strategy

### Decision: Project-Local Linking with Local Version-Control Exclusion

Instead of attempting to sync files back to the Windows host or requiring manual file management on Windows, standards and skills are linked directly into each project workspace on the remote Linux VM.

```
~/Projects/
├── zed-standards/                 # Canonical upstream standards repository
│   ├── AGENTS.md
│   └── skills/
│       ├── package-scaffolding/
│       ├── script-conventions/
│       └── ...
└── target-project/                # Any active development repository
    ├── AGENTS.md                  -> symlink to ~/Projects/zed-standards/AGENTS.md
    ├── .agents/skills/
    │   ├── package-scaffolding/   -> symlink to ~/Projects/zed-standards/skills/package-scaffolding
    │   └── ...
    └── .git/info/exclude          # Excludes AGENTS.md and .agents/ from version control
```

### Advantages

1. **Native Client Discovery**:
   Because Zed scans `<workspace-root>/AGENTS.md` and `<workspace-root>/.agents/skills/` on the remote workspace, the Windows client automatically discovers all skills and instructions when opening the project.
2. **Zero Windows Host Overhead**:
   Developers do not need to install PowerShell scripts, configure Windows paths, or maintain duplicate copies of markdown files on the Windows filesystem.
3. **Instant Upstream Propagation**:
   When `zed-standards` is updated (`jj git fetch` or `git pull`) on the remote VM, all linked projects immediately inherit updated skills and instructions without reinstallation.
4. **Clean Working Copy (No Team Pollution)**:
   Personal standards symlinks must never be pushed to shared upstream repositories. By automatically appending `.agents/` and `AGENTS.md` to `.git/info/exclude`, the files remain untracked and invisible to `jj status` and `git status` without altering shared `.gitignore` files.

---

## 3. Instruction Lifecycle & Collision Handling

When applying `zed-standards` to a target repository:

1. **Skills (`.agents/skills/`)**:
   - Every skill is directory-isolated (`.agents/skills/<skill-name>/`).
   - The installer creates the directory and creates symlinks for each skill found in `zed-standards/skills/*`.
   - Existing project-specific skills are preserved without collision.
2. **Instructions (`AGENTS.md`)**:
   - **Scenario A (No existing `AGENTS.md`)**: Symlink `AGENTS.md -> ~/Projects/zed-standards/AGENTS.md`.
   - **Scenario B (Existing `AGENTS.md`)**: The installer respects existing repository instructions and leaves the file untouched.
3. **Version Control Safety**:
   - Target `.git/info/exclude` is automatically updated with `.agents/` and `AGENTS.md`.
   - Jujutsu (`jj`) respects `.git/info/exclude` when backed by a Git repository, ensuring working copies remain clean.

---

## 4. Target Host Provisioning (Local Execution)

To minimize startup friction on a newly cloned target Linux machine (whether it is a dev VM, SSH server, cloud instance, or physical server), a two-phase bootstrap pattern is executed **locally on that host**:

1. **Phase 1: Host Provisioning (`admin/host-bootstrap.sh`)**:
   - Run from the cloned `zed-standards` repository (`~/Projects/zed-standards`).
   - Installs or upgrades Jujutsu (`jj`) to the latest release via `admin/jj-install.sh`.
   - Provisions modular `~/.bashrc.d/` directory and prompts before wiring the loader into `~/.bashrc`.
   - Drops `~/.bashrc.d/local-bin.bash` (PATH for `~/.local/bin`).
   - Symlinks `~/.local/lib/dev-bootstrap` to `zed-standards/lib` for shared operational helpers.
2. **Phase 2: Project Onboarding (`install.sh --project <path>`)**:
   - Run once per cloned or initialized repository:
     ```bash
     cd ~/Projects/<app>
     ~/Projects/zed-standards/install.sh --project .
     ```
   - Automatically symlinks skills, links `AGENTS.md`, and updates `.git/info/exclude`.

---

## 5. Shared Developer Platform Library (`~/.local/lib/dev-bootstrap`)

To eliminate boilerplate duplication across administrative and operational scripts in multiple repositories, `zed-standards` provides a centralized procedural library:

```text
~/.local/lib/dev-bootstrap/ -> ~/Projects/zed-standards/lib/
├── lib-common.sh              # Single-line include loader for all modules
├── lib-platform.sh            # OS (linux/darwin) and CPU architecture (amd64, arm64, musl) detection
├── lib-site.sh                # Deterministic site selection (CLI $1 with interactive menu fallback)
├── lib-deploy.sh              # Safe file placement with change detection, diff prompts, and permissions
├── lib-secret.sh              # Diceware passphrase generator & proof-of-capture ceremony
├── lib-cidata.sh              # NoCloud Cloud-Init ISO generation helper
└── lib-telemetry.sh           # Healthchecks.io & NTFY push notification alerting helpers
```

### Usage in Other Repositories
Any management or operational script in any repository on the host can source shared primitives:
```bash
source "${HOME}/.local/lib/dev-bootstrap/lib-common.sh"

ARCH="$(detect_arch_alias)"       # "amd64" or "arm64"
SITE="$(resolve_site "${1:-}")"   # CLI arg or numbered menu
```
Because `~/.local/lib/dev-bootstrap` is a symlink to `zed-standards/lib`, improvements made to platform primitives are instantly available across all repositories on that host without running secondary deployment commands.

---

## 6. Two Audiences: Dual-Purpose Repository Architecture

This body of work serves two distinct audiences with different requirements:

```
Audience A: Developer Workstations & Interactive AI Sessions
┌──────────────────────────────────────────────────────────────────┐
│ • Needs: AGENTS.md + .agents/skills/ + dev-bootstrap library     │
│ • Installed via: ./install.sh --project <path>  OR  --all        │
│ • Tooling: explicit ./install.sh --project CLI workflow          │
└──────────────────────────────────────────────────────────────────┘

Audience B: Headless Servers, Automation, CI/CD, & Production Nodes
┌──────────────────────────────────────────────────────────────────┐
│ • Needs: dev-bootstrap library ONLY (~/.local/lib/dev-bootstrap) │
│ • Installed via: ./install.sh --lib-only                         │
│ • Tooling: jj-install.sh, lib-deploy, lib-site, lib-telemetry   │
│ • Zero AI overhead: does not install editor agent skills/prompts │
└──────────────────────────────────────────────────────────────────┘
```

### Decoupling Strategy & Structural Boundaries
To ensure that splitting these two concerns into separate repositories in the future is a zero-friction operation:
1. **The Declarative "Brain"** (`AGENTS.md`, `skills/`): Contains all LLM agent instructions, architectural axioms, and skill catalogs.
2. **The Procedural "Muscle"** (`lib/`, `admin/`): Contains standalone POSIX/Bash shell scripts that execute deployments, binary installations, and hardware/OS detection.
3. **The Installer Entry Points**:
   - `install.sh --lib-only` provisions solely the procedural platform library.
   - `admin/host-bootstrap.sh --lib-only` sets up headless production servers without editor artifacts.
