# Remote Development, Peer Jujutsu Synchronization & SSH Deployment

This document provides architectural standards and step-by-step procedures for managing development between a primary controller machine (e.g. **WSL / Local Workstation**) and one or more **Remote Target Nodes** (test VMs, staging boxes, bare-metal servers).

---

## 1. What to Do with Zed on Remote Machines

When using WSL as your primary development seat, remote machines serve primarily as **execution and test targets**, not editor frontends.

### Treat Remote Nodes as Headless (Audience B)
Target machines only require the shared platform scripts (`lib/`), not AI agent skills or editor axioms:
1. **Bootstrap Headless Only**: Run `./install.sh --lib-only` on target machines. This wires `~/.local/lib/dev-bootstrap` without generating local agent skills or workspace hooks.
2. **Strip Personal Links with `--clean`**: On any repository checked out on a remote machine, run:
   ```bash
   ~/Projects/zed-standards/install.sh --clean <path-to-repo>
   ```
   This safely identifies and removes only symlinks pointing to `zed-standards` (`AGENTS.md`, `.agents/skills/*`), while preserving any project-native agent files or non-standards skills.
3. **Rely on `.gitignore`**: Because `.agents/`, `AGENTS.md`, and `.zed/` are ignored in `.gitignore`, target machines will never accidentally commit local editor state.

---

## 2. What to Do with Existing Repositories on Remote Machines

Do **not** delete existing repositories on remote nodes. They often hold custom test configurations (`site-conf/`), active test state, or local debug edits. Instead, convert them into direct SSH peer remotes.

### Jujutsu Auto-Commit Dynamics
Jujutsu automatically tracks working tree edits. If you test or tweak code on a remote machine without coordinating with WSL, commit drift occurs:
* Machine A commits changes to `main`.
* Machine B independently creates working commits on older revisions.
* Pulling or pushing causes divergent heads or abandoned commits.

### Solution: Direct Peer-to-Peer SSH Remotes
Rather than using GitHub as a slow relay for debugging loops, connect WSL directly to the remote repository:

```bash
# On WSL, add the remote repository as a direct peer:
jj git remote add testbox ssh://ubuntu@<remote-ip>/home/ubuntu/Projects/<project-name>/.jj/repo/store/git
```

Now WSL can inspect and interact with the remote node's working copy directly:
```bash
# Fetch latest state from the remote box:
jj --no-pager git fetch --remote testbox

# View what was changed during remote debugging:
jj --no-pager diff --from main --to testbox/main
```

The Zed agent in WSL has 100% visibility into remote edits and can cherry-pick, clean up, or merge them.

---

## 3. Direct SSH Deployment of `zed-standards` (LAN / Mesh)

Instead of cloning `zed-standards` from GitHub on every remote test node, deploy it directly from WSL over SSH.

### Why Avoid GitHub on Target Nodes
* Eliminates the need to copy GitHub SSH keys or access tokens to ephemeral test nodes.
* Works on isolated lab VLANs without outbound internet access.
* Deploys your local modifications immediately without requiring an upstream GitHub push.

### One-Command Deployment from WSL

Add this alias or helper script to WSL (`~/.bashrc.d/zed-standards.bash`):

```bash
deploy-standards() {
    local remote_host="$1"
    if [[ -z "$remote_host" ]]; then
        echo "Usage: deploy-standards user@host" >&2
        return 1
    fi

    echo "[*] Syncing zed-standards to $remote_host..."
    rsync -avz --delete \
        --exclude='.git' \
        --exclude='.jj' \
        ~/Projects/zed-standards/ "${remote_host}:~/Projects/zed-standards/"

    echo "[*] Bootstrapping platform library on $remote_host..."
    ssh "$remote_host" "bash ~/Projects/zed-standards/admin/host-bootstrap.sh --lib-only"
}
```

---

## 4. Recommended Action Plan & Daily Operating Procedure

### Phase A: Setup Target Nodes (One-Time)
1. **Push `zed-standards` over SSH**:
   ```bash
   deploy-standards ubuntu@<remote-ip>
   ```
2. **Clean Project Repositories**:
   On the remote node, strip personal zed symlinks:
   ```bash
   ~/Projects/zed-standards/install.sh --clean ~/Projects/<project-name>
   ```
3. **Register Peer Remote in WSL**:
   In your project on WSL:
   ```bash
   jj git remote add <nodename> ssh://ubuntu@<remote-ip>/home/ubuntu/Projects/<project-name>/.jj/repo/store/git
   ```

---

### Phase B: Daily Iterative Debugging Loop

When testing code across WSL and the remote node:

#### 1. Push code from WSL to Remote Node (Before Testing)
```bash
# Push working branch directly to the test box:
jj git push --remote <nodename> --bookmark main

# On the test box, update the working copy:
ssh ubuntu@<remote-ip> "cd ~/Projects/<project-name> && jj --no-pager new main"
```

*(Alternative for rapid, uncommitted live test tweaks:)*
```bash
rsync -av --exclude='.git' --exclude='.jj' ./ ubuntu@<remote-ip>:~/Projects/<project-name>/
```

#### 2. Harvest Remote Debug Tweaks back to WSL (After Testing)
If you made changes on the test node during debugging:
1. **On the test box**, record the changes:
   ```bash
   jj describe -m "debug: remote fix for <issue>"
   ```
2. **On WSL**, fetch and inspect:
   ```bash
   jj --no-pager git fetch --remote <nodename>
   jj --no-pager diff --from main --to <nodename>/main
   ```
3. Ask the Zed agent:
   > *"Review the diff on `<nodename>`, clean up the debugging hacks, and merge the fix into `main`."*
4. Seal and push cleanly to GitHub from WSL:
   ```bash
   jj describe -m "Fix <issue> observed during remote testing"
   jj new
   jj bookmark set main -r @-
   jj git push --remote origin --bookmark main
   ```
