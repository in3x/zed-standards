#!/usr/bin/env python3
"""
Zed Standards & Developer Platform Library Installer
Manages project workspace links, global configuration, and the shared dev-bootstrap library.
"""

from __future__ import annotations

import argparse
import os
import shutil
import sys
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent
SKILLS_DIR = REPO_DIR / "skills"
LIB_DIR = REPO_DIR / "lib"
SOURCE_AGENTS = REPO_DIR / "AGENTS.md"


def link_project(raw_target: Path | str = ".") -> int:
    target_proj = Path(raw_target).resolve()
    if not target_proj.is_dir():
        print(f"[-] Error: Project directory '{target_proj}' does not exist.", file=sys.stderr)
        return 1

    print(f"[+] Linking Zed standards to project: {target_proj}")

    # 1. Project Skills (.agents/skills/<skill-name>)
    proj_skills_dir = target_proj / ".agents" / "skills"
    proj_skills_dir.mkdir(parents=True, exist_ok=True)

    if SKILLS_DIR.is_dir():
        for skill in sorted(SKILLS_DIR.iterdir()):
            if not skill.is_dir():
                continue
            skill_name = skill.name
            dest_skill = proj_skills_dir / skill_name

            if dest_skill.is_symlink():
                dest_skill.unlink()
                dest_skill.symlink_to(skill, target_is_directory=True)
                print(f"    [+] Refreshed skill: .agents/skills/{skill_name} -> {skill}")
            elif dest_skill.exists():
                print(f"    [!] Notice: .agents/skills/{skill_name} is a local directory (left untouched).")
            else:
                dest_skill.symlink_to(skill, target_is_directory=True)
                print(f"    [+] Linked skill: .agents/skills/{skill_name} -> {skill}")

    # 2. AGENTS.md (Non-destructive)
    target_agents = target_proj / "AGENTS.md"
    if target_agents.is_symlink():
        target_agents.unlink()
        target_agents.symlink_to(SOURCE_AGENTS)
        print(f"    [+] Refreshed symlink: AGENTS.md -> {SOURCE_AGENTS}")
    elif target_agents.exists():
        print("    [!] Notice: Project has an existing AGENTS.md file (left untouched).")
    else:
        target_agents.symlink_to(SOURCE_AGENTS)
        print(f"    [+] Linked AGENTS.md -> {SOURCE_AGENTS}")

    # 3. Prevent Git / Jujutsu working-copy pollution
    git_dir = target_proj / ".git"
    if git_dir.is_dir():
        exclude_file = git_dir / "info" / "exclude"
        exclude_file.parent.mkdir(parents=True, exist_ok=True)
        existing_lines = exclude_file.read_text(encoding="utf-8").splitlines() if exclude_file.is_file() else []
        new_entries = []
        for entry in [".agents/", "AGENTS.md"]:
            if entry not in existing_lines:
                new_entries.append(entry)
        if new_entries:
            with exclude_file.open("a", encoding="utf-8") as f:
                if existing_lines and existing_lines[-1].strip() != "":
                    f.write("\n")
                for entry in new_entries:
                    f.write(f"{entry}\n")
                    print(f"    [+] Registered '{entry}' in .git/info/exclude")
    elif (target_proj / ".jj").is_dir():
        # Pure Jujutsu repo without .git: ensure .gitignore has entries
        gitignore = target_proj / ".gitignore"
        existing_lines = gitignore.read_text(encoding="utf-8").splitlines() if gitignore.is_file() else []
        new_entries = [e for e in [".agents/", "AGENTS.md"] if e not in existing_lines]
        if new_entries:
            with gitignore.open("a", encoding="utf-8") as f:
                if existing_lines and existing_lines[-1].strip() != "":
                    f.write("\n")
                for entry in new_entries:
                    f.write(f"{entry}\n")
                    print(f"    [+] Registered '{entry}' in .gitignore")

    print(f"[+] Project setup complete for: {target_proj}")
    return 0


def clean_project(raw_target: Path | str = ".") -> int:
    target_proj = Path(raw_target).resolve()
    if not target_proj.is_dir():
        print(f"[-] Error: Project directory '{target_proj}' does not exist.", file=sys.stderr)
        return 1

    print(f"[+] Cleaning zed-standards symlinks from: {target_proj}")

    # 1. Clean AGENTS.md symlink
    target_agents = target_proj / "AGENTS.md"
    if target_agents.is_symlink():
        target_agents.unlink()
        print("    [+] Removed symlink: AGENTS.md")
    elif target_agents.exists():
        print("    [!] Preserved project-authored file: AGENTS.md")

    # 2. Clean .agents/skills/ symlinks
    proj_skills_dir = target_proj / ".agents" / "skills"
    if proj_skills_dir.is_dir():
        for item in sorted(proj_skills_dir.iterdir()):
            if item.is_symlink():
                item.unlink()
                print(f"    [+] Removed skill symlink: {item.name}")
            else:
                print(f"    [!] Preserved local skill: {item.name}")

        # Remove skills directory if empty
        try:
            proj_skills_dir.rmdir()
            (target_proj / ".agents").rmdir()
            print("    [+] Cleaned empty .agents/ container directory.")
        except OSError:
            pass

    print(f"[+] Clean complete for: {target_proj}")
    return 0


def link_lib_only() -> int:
    user_lib_dir = Path.home() / ".local" / "lib"
    user_lib_dir.mkdir(parents=True, exist_ok=True)
    target_symlink = user_lib_dir / "dev-bootstrap"

    print("[+] Installing dev-bootstrap shared platform library (Audience B / Headless)...")
    if target_symlink.is_symlink() or target_symlink.exists():
        if target_symlink.is_symlink() or target_symlink.is_file():
            target_symlink.unlink()
        else:
            shutil.rmtree(target_symlink)

    target_symlink.symlink_to(LIB_DIR, target_is_directory=True)
    print(f"    [+] Linked: {target_symlink} -> {LIB_DIR}")
    print("    Available modules:")
    for mod in sorted(LIB_DIR.glob("lib-*.sh")):
        print(f"      - {mod.name}")
    print(f"[+] Platform library ready at: {target_symlink}")
    return 0


def link_global() -> int:
    xdg_config = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    zed_config_dir = xdg_config / "zed"
    zed_skills_dir = Path.home() / ".agents" / "skills"

    print(f"[+] Bootstrapping Zed global standards to: {Path.home()}")
    print(f"    Config dir: {zed_config_dir}")
    print(f"    Skills dir: {zed_skills_dir}")

    # 1. Global AGENTS.md
    zed_config_dir.mkdir(parents=True, exist_ok=True)
    global_agents = zed_config_dir / "AGENTS.md"
    if global_agents.is_symlink():
        global_agents.unlink()
        global_agents.symlink_to(SOURCE_AGENTS)
        print(f"    [+] Refreshed: {global_agents} -> {SOURCE_AGENTS}")
    elif global_agents.exists():
        bak_file = global_agents.with_name("AGENTS.md.bak")
        print(f"    [!] Notice: {global_agents} is an existing regular file.")
        print(f"        Backing up to {bak_file.name} before replacing with symlink.")
        shutil.copy2(global_agents, bak_file)
        global_agents.unlink()
        global_agents.symlink_to(SOURCE_AGENTS)
        print(f"    [+] Linked: {global_agents} -> {SOURCE_AGENTS}")
    else:
        global_agents.symlink_to(SOURCE_AGENTS)
        print(f"    [+] Linked: {global_agents} -> {SOURCE_AGENTS}")

    # 2. Global Skills (~/.agents/skills/)
    zed_skills_dir.mkdir(parents=True, exist_ok=True)
    if SKILLS_DIR.is_dir():
        for skill in sorted(SKILLS_DIR.iterdir()):
            if not skill.is_dir():
                continue
            skill_name = skill.name
            dest_skill = zed_skills_dir / skill_name

            if dest_skill.is_symlink():
                dest_skill.unlink()
                dest_skill.symlink_to(skill, target_is_directory=True)
                print(f"    [+] Refreshed skill: {dest_skill} -> {skill}")
            elif dest_skill.exists():
                print(f"    [!] Notice: {dest_skill} is a local directory (left untouched).")
            else:
                dest_skill.symlink_to(skill, target_is_directory=True)
                print(f"    [+] Linked skill: {dest_skill} -> {skill}")

    # 3. Shared Library (~/.local/lib/dev-bootstrap)
    link_lib_only()

    # 4. Check for client-remote architecture notice
    is_wsl = False
    proc_ver = Path("/proc/version")
    if proc_ver.is_file():
        is_wsl = "microsoft" in proc_ver.read_text(encoding="utf-8", errors="ignore").lower()

    if is_wsl or "SSH_CONNECTION" in os.environ:
        print()
        print("====================================================================")
        print(" [NOTICE] Remote / Client Architecture Detected")
        print("====================================================================")
        print(" If running Zed as a Windows client connecting to this Linux host,")
        print(" the Windows client reads global configuration from:")
        print(r"   - %APPDATA%\Zed\AGENTS.md")
        print(r"   - %USERPROFILE%\.agents\skills\\")
        print()
        print(" Global Linux links (~/.config/zed) will not be visible to the client.")
        print(" To enable these standards for your remote workspace, run:")
        print("   ./install.py --project <path-to-workspace>")
        print("====================================================================")

    print("[+] Global installation complete.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Zed Standards & Developer Platform Library Installer",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Profiles & Examples:
  %(prog)s --project .                 # [Audience A] Link standards into current workspace
  %(prog)s --project ~/Projects/my-app # [Audience A] Link into specific workspace
  %(prog)s --all                       # [Audience A] Full host install (skills + AGENTS.md + library)
  %(prog)s --lib-only                  # [Audience B] Headless server install (library only)
  %(prog)s --clean ~/Projects/my-app   # Safely unlink standards from a workspace
        """,
    )

    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "-p",
        "--project",
        nargs="?",
        const=".",
        metavar="PATH",
        help="Link skills and AGENTS.md into a project workspace (defaults to current directory).",
    )
    group.add_argument(
        "-a",
        "--all",
        "-g",
        "--global",
        dest="global_install",
        action="store_true",
        help="Full host setup: links skills, AGENTS.md, and platform library (~/.local/lib/dev-bootstrap).",
    )
    group.add_argument(
        "-l",
        "--lib-only",
        "--headless",
        dest="lib_only",
        action="store_true",
        help="Install ONLY the shared platform library (~/.local/lib/dev-bootstrap) for headless servers or CI/CD.",
    )
    group.add_argument(
        "-c",
        "--clean",
        nargs="?",
        const=".",
        metavar="PATH",
        help="Safely remove zed-standards symlinks from a project workspace.",
    )

    parser.add_argument(
        "target_dir",
        nargs="?",
        metavar="TARGET_PATH",
        help="Optional positional target directory (treated as --project <TARGET_PATH> if provided).",
    )

    args = parser.parse_args()

    # Route based on flags
    if args.project is not None:
        return link_project(args.project)
    elif args.clean is not None:
        return clean_project(args.clean)
    elif args.lib_only:
        return link_lib_only()
    elif args.global_install:
        return link_global()
    elif args.target_dir:
        target_path = Path(args.target_dir)
        if target_path.is_dir():
            return link_project(target_path)
        else:
            print(f"[-] Error: Directory '{args.target_dir}' does not exist.", file=sys.stderr)
            return 1
    else:
        parser.print_help()
        return 0


if __name__ == "__main__":
    sys.exit(main())
