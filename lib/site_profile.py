#!/usr/bin/env python3
"""
Universal Site Profile Management Engine (Stage 1 Lifecycle)
Handles deterministic site selection, template initialization, and non-destructive
deep merging for INI, JSON, and environment configuration profiles.
"""

from __future__ import annotations

import argparse
import os
import re
import secrets
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence, Tuple


# ==============================================================================
# 1. Deterministic Site Resolution
# ==============================================================================

def resolve_or_create_site(
    site_conf_dir: Path,
    cli_site: Optional[str] = None,
    allow_create: bool = True,
) -> str:
    """
    Resolves the active site ID deterministically.
    If cli_site is provided, validates and returns it.
    Otherwise, presents an interactive numbered menu.
    """
    site_conf_dir.mkdir(parents=True, exist_ok=True)

    # 1. Direct CLI argument
    if cli_site:
        clean_site = cli_site.strip()
        if not re.match(r"^[a-zA-Z0-9_-]+$", clean_site):
            print(f"[-] Error: Invalid site ID '{clean_site}'. Use alphanumeric, hyphen, or underscore.", file=sys.stderr)
            sys.exit(1)
        return clean_site

    # 2. Collect existing site directories
    sites: List[str] = sorted(
        [d.name for d in site_conf_dir.iterdir() if d.is_dir() and not d.name.startswith(".")]
    )

    if not sys.stdin.isatty():
        if sites:
            print(f"[-] Error: Non-interactive shell. Specify site on CLI: {sites}", file=sys.stderr)
        else:
            print("[-] Error: Non-interactive shell and no site specified.", file=sys.stderr)
        sys.exit(1)

    # 3. Interactive menu
    print("Select a site profile to manage:", file=sys.stderr)
    for idx, site in enumerate(sites, start=1):
        print(f"  {idx}) {site}", file=sys.stderr)

    create_option_index: Optional[int] = None
    if allow_create:
        create_option_index = len(sites) + 1
        print(f"  {create_option_index}) [Create new profile]", file=sys.stderr)

    total_choices = len(sites) + (1 if allow_create else 0)

    while True:
        try:
            choice = input(f"Selection [1-{total_choices}]: ").strip()
            if not choice:
                continue
            index = int(choice)
            if 1 <= index <= len(sites):
                return sites[index - 1]
            elif allow_create and index == create_option_index:
                new_id = input("Enter new site profile ID (e.g. lake, prod-east, lab): ").strip()
                if not new_id or not re.match(r"^[a-zA-Z0-9_-]+$", new_id):
                    print("[-] Error: Invalid site ID. Use alphanumeric, hyphen, or underscore.", file=sys.stderr)
                    sys.exit(1)
                return new_id
        except (ValueError, EOFError, KeyboardInterrupt):
            pass
        print(f"[-] Invalid selection. Enter a number between 1 and {total_choices}.", file=sys.stderr)
        sys.exit(1)


# ==============================================================================
# 2. Non-Destructive INI Merging Engine
# ==============================================================================

@dataclass
class IniParsed:
    lines: List[str]
    root_keys: List[str] = field(default_factory=list)
    sections: Dict[str, List[str]] = field(default_factory=dict)


def parse_ini_structure(content: str) -> IniParsed:
    """Parses raw INI text into ordered lines, root keys, and section keys."""
    lines = content.splitlines()
    root_keys: List[str] = []
    sections: Dict[str, List[str]] = {}
    current_sec: Optional[str] = None

    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith(("#", ";")):
            continue
        if stripped.startswith("[") and stripped.endswith("]"):
            current_sec = stripped[1:-1].strip()
            if current_sec not in sections:
                sections[current_sec] = []
        elif "=" in stripped:
            key = stripped.split("=", 1)[0].strip()
            if current_sec is None:
                root_keys.append(key)
            else:
                sections[current_sec].append(key)

    return IniParsed(lines=lines, root_keys=root_keys, sections=sections)


def merge_ini(template_text: str, site_text: str) -> Tuple[str, List[str], List[Tuple[str, str]]]:
    """
    Non-destructively merges template defaults into existing site INI text.
    Preserves all site customizations, comments, and whitespace.
    Returns: (merged_text, added_sections, added_keys)
    """
    t_parsed = parse_ini_structure(template_text)
    s_parsed = parse_ini_structure(site_text)

    result_lines = list(s_parsed.lines)
    added_sections: List[str] = []
    added_keys: List[Tuple[str, str]] = []

    # 1. Check missing root keys
    for key in t_parsed.root_keys:
        if key not in s_parsed.root_keys:
            # Find the template line for this key
            for line in t_parsed.lines:
                stripped = line.strip()
                if stripped.startswith(key + " ") or stripped.startswith(key + "="):
                    # Insert before the first section header in result
                    insert_idx = len(result_lines)
                    for idx, r_line in enumerate(result_lines):
                        if r_line.strip().startswith("["):
                            insert_idx = idx
                            break
                    result_lines.insert(insert_idx, line)
                    added_keys.append(("(root)", key))
                    break

    # 2. Check missing sections and missing keys within existing sections
    for sec_name, sec_keys in t_parsed.sections.items():
        if sec_name not in s_parsed.sections:
            # Whole section is missing: extract the entire block from template
            section_block: List[str] = []
            in_section = False
            for line in t_parsed.lines:
                stripped = line.strip()
                if stripped.startswith("[") and stripped.endswith("]"):
                    cur = stripped[1:-1].strip()
                    if cur == sec_name:
                        in_section = True
                    elif in_section:
                        break
                if in_section:
                    section_block.append(line)

            if result_lines and result_lines[-1].strip() != "":
                result_lines.append("")
            result_lines.extend(section_block)
            added_sections.append(sec_name)
        else:
            # Section exists: check for missing individual keys
            existing_sec_keys = s_parsed.sections[sec_name]
            for key in sec_keys:
                if key not in existing_sec_keys:
                    key_line: Optional[str] = None
                    in_section = False
                    for line in t_parsed.lines:
                        stripped = line.strip()
                        if stripped.startswith("[") and stripped.endswith("]"):
                            in_section = (stripped[1:-1].strip() == sec_name)
                        elif in_section and (stripped.startswith(key + " ") or stripped.startswith(key + "=")):
                            key_line = line
                            break

                    if key_line is not None:
                        # Insert right after the section header
                        for idx, r_line in enumerate(result_lines):
                            if r_line.strip() == f"[{sec_name}]":
                                result_lines.insert(idx + 1, key_line)
                                added_keys.append((sec_name, key))
                                break

    merged_output = "\n".join(result_lines) + "\n"
    return merged_output, added_sections, added_keys


# ==============================================================================
# 3. Cryptographic Token Helpers
# ==============================================================================

def generate_secret_token(nbytes: int = 32) -> str:
    """Generates a cryptographically strong URL-safe secret token."""
    return secrets.token_urlsafe(nbytes)


# ==============================================================================
# 4. CLI Entry Point
# ==============================================================================

def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Universal Site Profile Manager (Stage 1 Lifecycle)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("site", nargs="?", help="Site profile name from site-conf/")
    parser.add_argument(
        "-t",
        "--template",
        type=Path,
        required=True,
        help="Path to canonical upstream template (e.g. conf/app.ini)",
    )
    parser.add_argument(
        "-s",
        "--site-conf",
        type=Path,
        default=Path("site-conf"),
        help="Path to site profiles directory (default: site-conf)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simulate the merge without modifying site configuration files",
    )
    parser.add_argument(
        "--domain",
        help="Domain FQDN override for initial template placeholder substitution",
    )

    args = parser.parse_args(argv)

    template_path: Path = args.template.resolve()
    if not template_path.is_file():
        print(f"[-] Error: Canonical template not found at {template_path}", file=sys.stderr)
        return 1

    site_conf_dir: Path = args.site_conf.resolve()
    site_id = resolve_or_create_site(site_conf_dir, args.site)

    target_dir = site_conf_dir / site_id
    target_config = target_dir / template_path.name

    template_text = template_path.read_text(encoding="utf-8")

    # Run 1: Greenfield Initialization
    if not target_config.exists():
        print(f"[+] Initializing new site profile: {site_id}")
        target_dir.mkdir(parents=True, exist_ok=True)

        domain = args.domain
        if not domain and sys.stdin.isatty():
            domain = input(f"Domain FQDN (default: {site_id}.dc.paradigm-works.com): ").strip()
        domain = domain or f"{site_id}.dc.paradigm-works.com"

        # Generate secrets
        lfs_secret = generate_secret_token()
        internal_token = generate_secret_token()
        jwt_secret = generate_secret_token()

        # Substitutions
        rendered = template_text
        rendered = rendered.replace("{{DOMAIN}}", domain)
        rendered = rendered.replace("{{LFS_JWT_SECRET}}", lfs_secret)
        rendered = rendered.replace("{{INTERNAL_TOKEN}}", internal_token)
        rendered = rendered.replace("{{JWT_SECRET}}", jwt_secret)

        if not args.dry_run:
            target_config.write_text(rendered, encoding="utf-8")
            os.chmod(target_config, 0o600)
            print(f"[+] Successfully created {target_config}")
            print(f"    Domain:         {domain}")
            print("    Generated keys: LFS_JWT_SECRET, INTERNAL_TOKEN, JWT_SECRET")
        else:
            print(f"[+] [DRY-RUN] Would create {target_config} with domain {domain}")
        return 0

    # Run N: Non-destructive Merge
    print(f"[+] Existing profile detected: {target_config}")
    print("[+] Running non-destructive template sync (checking for missing sections & keys)...")

    site_text = target_config.read_text(encoding="utf-8")
    merged_text, added_secs, added_keys = merge_ini(template_text, site_text)

    if added_secs or added_keys:
        if not args.dry_run:
            target_config.write_text(merged_text, encoding="utf-8")
            print(f"[+] Added {len(added_secs)} missing sections and {len(added_keys)} missing keys to {target_config}")
        else:
            print(f"[+] [DRY-RUN] Would add {len(added_secs)} sections and {len(added_keys)} keys to {target_config}")

        for sec in added_secs:
            print(f"    + Section: [{sec}]")
        for sec, key in added_keys:
            print(f"    + Key: [{sec}] {key}")
    else:
        print("[+] All template sections and keys are present. No additions needed.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
