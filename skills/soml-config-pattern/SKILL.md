---
name: soml-config-pattern
description: Standards, syntax rules, and tooling patterns for SOML (Sindre's Objectively Marvelous Language), handling upstream templates, comment-preserving formatting, and two-stage lifecycle operations.
---

# SOML Configuration Pattern

SOML (Sindre's Objectively Marvelous Language) is a human-oriented configuration format designed as "JSON without the noise, with comments, and without YAML's type guessing."

Specification: [https://github.com/soml-lang/soml](https://github.com/soml-lang/soml)

## 1. Directory & File Placement
SOML configurations follow the two-stage lifecycle:
```text
project-root/
├── conf/
│   └── app.soml               # Upstream template with defaults & comments
└── site-conf/
    ├── site-a/
    │   └── app.soml           # Site-specific values (non-secret)
    └── site-b/
        └── app.soml
```
- **File extension**: `.soml`
- **Encoding**: UTF-8 without BOM; **LF line endings only** (CR / `\r` is strictly forbidden).

## 2. Core Syntax & Design Axioms

### A Value's Type Comes from Syntax, Never Content
- `'123'` is always a string; `123` is an int; `123.0` is a float.
- `true` and `false` are booleans; `'true'` is a string. Unquoted `no` or `yes` are syntax errors, not booleans.

### Top-Level Document & Punctuation
- The top-level object requires **no surrounding braces** (`{}`).
- Commas are optional when entries or array items are separated by line breaks.
- Colon follows key immediately with no preceding space (`key: value`).
- Duplicate keys are syntax errors (evaluated on decoded string value).

### Keys
- **Bare keys**: Letters, digits, underscores, dashes (`launch-date:`, `api-gateway:`, `404:`, `_private:`).
- **Quoted keys**: Required only if the key contains spaces, dots (`.`), colons, or characters outside `[A-Za-z0-9_-]` (e.g., `'the name':`, `'example.com':`).

### Strings
- **Literal strings (`'...'`)**: Default choice. No escape sequences; backslashes are literal (ideal for regexes and Windows paths: `'C:\Users\sindre\dev'`).
- **Escaped strings (`"..."`)**: Supports `\\`, `\"`, `\n`, `\t`, and Unicode scalar escapes `\u{…}` (e.g., `"\u{1f600}"`).
- **Block strings (`'''...'''` / `"""..."""`)**: Dedented automatically based on the closing delimiter's column.

### Native Data Types
- **Integers**: 64-bit signed decimal (`3`, `1_000_000`), hex (`0xFF`), octal (`0o644`), binary (`0b1010`).
- **Floats**: IEEE 754 binary64 (`0.75`, `1e5`, `infinity`, `-infinity`). No `nan`.
- **Temporal Types**:
  - `date`: Calendar date `YYYY-MM-DD` (e.g., `2027-09-19`).
  - `instant`: RFC 3339 timestamp with mandatory offset (e.g., `2026-09-19T14:00:00Z`).
  - `duration`: Nanosecond-accurate units in descending order (`30s`, `1m30s`, `1.5s`, `250ms`, `-5m`).
- **Collections**:
  - Arrays: `['prod', 'canary']` or multi-line without commas:
    ```soml
    allowed-origins: [
    	'https://example.com'
    	'https://example.org'
    ]
    ```
  - Objects: `{min: 2, max: 16}` or multi-line:
    ```soml
    pool: {
    	min: 2
    	max: 16
    }
    ```

### Comments
- Line comments: `# comment`
- Block comments: `/* multiline comment */`

## 3. Example SOML Configuration
```soml
# Production Service Configuration
name: 'api-gateway'
port: 8080
timeout: 30s
launch-date: 2027-09-19

# Paths use literal single quotes (no escaping needed)
storage-path: '/var/lib/api-gateway'

pool: {
	min: 4
	max: 32
}

allowed-hosts: [
	'api.example.com'
	'internal.example.org'
]
```

## 4. Two-Stage Merge Lifecycle
When syncing upstream `conf/app.soml` into `site-conf/<site>/app.soml`:
1. **Preserve Comments & Author Layout**: Comments and customized values in `site-conf/<site>/app.soml` must remain intact.
2. **Inject Missing Upstream Keys**: Newly added keys/sections from `conf/app.soml` are appended with their template default values and documentation.
3. **Format Normalization**:
   - Tab indentation for nested objects/arrays.
   - Enforce LF line endings.
   - Ensure clean validation via the SOML parser.

## 5. Tooling & Automation

### Python Integration
When working with SOML in Python, use the `soml` package (or conformance-tested parser):
```python
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "soml",
# ]
# ///

from pathlib import Path
import soml

def validate_soml(path: Path) -> bool:
    try:
        content = path.read_text(encoding="utf-8")
        if "\r" in content:
            raise ValueError("SOML forbids carriage return (CR) characters.")
        soml.parse(content)
        return True
    except Exception as e:
        print(f"[-] Invalid SOML in {path}: {e}")
        return False
```

### Pre-commit / Shell Check
Ensure line endings are strictly LF:
```bash
if grep -q $'\r' path/to/config.soml; then
    echo "[-] Error: SOML forbids carriage returns (CR/CRLF). Convert to LF." >&2
    exit 1
fi
```
