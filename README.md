<div align="center">

# token-thrift

**Security-first code review for sensitive codebases.**

A hardened CLI that indexes your codebase into a local knowledge graph so AI assistants only read what they need, with strict guardrails around wallets, keys, and secrets.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-linux%20%7C%20macos%20%7C%20termux-blue?style=flat-square)](#)
[![Python](https://img.shields.io/badge/python-3.10%2B-blue?style=flat-square)](#)

</div>

---

## Why token-thrift

Most AI code review tools optimize for efficiency. token-thrift optimizes for **safety first, efficiency second**.

Built for trading bots, wallet utilities, codebases that contain `.env` secrets, and any project where supply-chain attacks or accidental data exposure are real concerns.

| Feature | What it gives you |
|---------|-------------------|
| 🔒 Pre-flight scanner | Detects `*.key`, `wallet*.json`, `.env`, `*mnemonic*` and refuses to index them until properly ignored. |
| 🌐 Cloud egress disabled by default | Cloud API env vars (OpenAI, Google, MiniMax) are unset at runtime. A socket-level guard also blocks known cloud hosts. |
| ✅ SHA256-verified install | Both the main wheel and (when a lock file is present) every transitive dependency are hash-checked before installation. |
| 📦 Isolated execution | Runs inside a pipx-managed virtualenv. Your global Python stays untouched. |
| 🚫 No aggressive hooks | Editor configs (.cursor, .windsurf, .zed) and git hooks are never modified. |
| 🛡️ Global ignore template | Ships with safe defaults for wallets, keys, secrets, and crypto artifacts. |
| 🧬 Tamper-evident wrapper | The wrapper hashes itself at install time and refuses to run if it has been modified. |
| 📜 Audit log | Every invocation appended to `~/.token-thrift/audit.log` for forensics. |
| 🔍 Content secret scanner | Regex-based scan for inline secrets (PEM keys, API tokens, mnemonics). |
| 📂 Extension allowlist | Defense in depth: warn on file types outside a known-safe allowlist. |
| 🔐 Encrypted backup | One-command `backup` and `restore` of state, using age, gpg, or openssl. |
| 🔄 Self-update | `token-thrift self-update` pulls the latest release with optional GPG verification. |

---

## Quick Install

```bash
git clone https://github.com/djproject-id/token-thrift.git
cd token-thrift
bash install.sh
```

The installer will:

1. Check for Python 3.10 or higher.
2. Install pipx if it is missing.
3. Verify the SHA256 of the main package wheel before installing.
4. If `requirements.lock` is present, enforce `--require-hashes` for every transitive dependency.
5. Install the engine inside an isolated pipx venv.
6. Drop the `token-thrift` wrapper into `~/.local/bin/` (chmod 700).
7. Place helper libraries in `~/.token-thrift/lib/` and data files in `~/.token-thrift/data/` (chmod 600).
8. Snapshot the wrapper, MCP config, and pipx venv binaries (SHA256) for tamper detection.
9. Register the MCP server in `~/.claude.json` (chmod 600).

Restart Claude Code and the tool is active.

---

## Usage

### Core review commands

```bash
token-thrift build              # Parse the codebase in cwd, after a pre-flight scan.
token-thrift update             # Refresh the graph, after a pre-flight scan.
token-thrift status             # Show graph status.
token-thrift help               # Full command list.
```

### Safety scanners

```bash
token-thrift scan ~/myproject         # Filename-based check for sensitive files.
token-thrift secret-scan ~/myproject  # Content-level regex scan for inline secrets.
token-thrift ext-scan ~/myproject     # Flag files with extensions outside the allowlist.
token-thrift init ~/myproject         # Drop the default ignore template into a project.
```

### Operations

```bash
token-thrift audit              # Show the last 50 audit-log entries.
token-thrift audit-path         # Print the audit log path.
token-thrift verify             # Re-run all integrity checks (wrapper, MCP, venv).
token-thrift backup out.age     # Encrypted backup of ~/.token-thrift/.
token-thrift restore out.age    # Restore from an encrypted backup.
token-thrift self-update        # Pull and reinstall the latest release.
```

Other subcommands pass through transparently to the underlying CLI, but always under the security guardrails described below.

---

## Blocked Subcommands (For Your Safety)

| Subcommand | Reason for blocking |
|------------|---------------------|
| `install` | Modifies many system files (settings, git hooks). Use the bundled installer instead. |
| `apply-refactor` | Writes directly to source files. Use your editor instead. |
| `cross-repo-search` | The cross-repo registry has minimal validation. Path traversal risk. |

---

## Pre-Flight Scanner

Before `build` or `update`, the scanner looks for any file matching:

```
*.key, *.pem, id_rsa*, id_ed25519*, *.gpg
wallet*.json, keypair*.json, phantom*.json, solflare*.json, backpack*.json
.env, *.env, secrets.json, auth.json, credentials*
*mnemonic*, *passphrase*, *seed.json, *master.key
```

If any match is found that is not already in `.code-review-graphignore`, the build halts. To override, type the literal phrase `i-accept-the-risk`. Intentional friction, so an accident never indexes your wallet.

The content-level secret scanner runs alongside the filename check and looks for inline patterns inside text files (PEM keys, API tokens, mnemonics). See `data/secret-patterns.txt` for the full list. Customize freely.

---

## Threat Model

token-thrift protects against:

- ✅ Supply-chain attacks (SHA256 verification of the main wheel, plus `--require-hashes` over transitive deps when a lock file is present).
- ✅ Cloud data leakage (cloud env vars are forcibly unset, plus a socket-level network guard refuses outbound connections to known cloud hosts).
- ✅ Aggressive auto-config (dangerous subcommands are blocked).
- ✅ Wallet or seed files indexed by mistake (filename + content scanners, plus a file-extension allowlist).
- ✅ Cross-repo path traversal (`cross-repo-search` is blocked).
- ✅ Global Python pollution (pipx-isolated venv).
- ✅ Tampered wrapper (self-hashes at startup, refuses to run on mismatch).
- ✅ Tampered MCP config (`~/.claude.json` hash watcher warns on drift).

token-thrift does NOT protect against:

- ❌ Zero-day bugs in the parser or SQLite. Run with a paranoid mindset.
- ❌ Compromise of `~/.claude.json`. Guard this file (chmod 600 set at install).
- ❌ Compromise of the pipx venv binary. Reinstall if the venv snapshot drifts.
- ❌ Untrusted patterns in your own `data/` files. Audit before customizing.

---

## Multi-Device Setup

Clone the repo on the second device, run `bash install.sh`. Each device gets its own isolated install.

Optionally regenerate `requirements.lock` for that platform if it differs from the originally generated lock:
```bash
bash scripts/gen-lock.sh
```

---

## Verify Yourself

The main wheel SHA256 verified at install time:

```
08d715607aefde3414d28b3a7844243823b150dc63ba4dd4529d6919f540d048
```

Verify manually:
```bash
pip download --no-deps code-review-graph==2.3.2
sha256sum code_review_graph-2.3.2-py3-none-any.whl
```

If `requirements.lock` is committed, every transitive dependency is also pinned. The lock file is generated by `scripts/gen-lock.sh` on a trusted machine and committed to the repo.

---

## File Layout

After install:

```
~/.local/bin/token-thrift               # Main wrapper (chmod 700)
~/.token-thrift/
    global-ignore                       # Default ignore patterns
    wrapper.sha256                      # Hash of the wrapper at install time
    claude.json.sha256                  # Hash of ~/.claude.json at install time
    pipx-venv.sha256                    # Hash list of pipx venv binaries
    audit.log                           # Append-only audit log
    lib/
        integrity.sh                    # Hash storage and verification helpers
        audit.sh                        # Audit-log helpers
        allowlist.sh                    # Extension-allowlist scanner
        secret-scan.sh                  # Content-level secret scanner
        backup.sh                       # Encrypted backup and restore
        selfupdate.sh                   # Self-update from GitHub
        network-guard.py                # Runtime socket-level egress guard
    data/
        secret-patterns.txt             # Regex patterns for content scanner
        allowed-extensions.txt          # File-type allowlist
        blocked-hosts.txt               # Network egress blocklist
```

In each project the wrapper auto-creates `.code-review-graphignore` from the global template on first build.

---

## Architecture

token-thrift consists of:

- `install.sh`: Verified installer with SHA256 checks, pipx isolation, MCP registration, and integrity snapshots.
- `token-thrift`: Bash wrapper that adds the pre-flight scanner, env-var hardening, runtime network guard, and subcommand guards.
- `lib/`: Sourced helper scripts for integrity, auditing, scanning, backup, and self-update.
- `data/`: User-customizable patterns and lists (secret regex, extension allowlist, host blocklist).
- `scripts/gen-lock.sh`: Regenerates `requirements.lock` with SHA256 hashes for every transitive dep.

Knowledge graph engine: [code-review-graph](https://pypi.org/project/code-review-graph/) on PyPI, pinned to version 2.3.2 with SHA256 verification.

AI integration: MCP (Model Context Protocol). Compatible with Claude Code and any other MCP-aware client.

---

## Uninstall

```bash
pipx uninstall code-review-graph
rm ~/.local/bin/token-thrift
rm -rf ~/.token-thrift
# Remove the "token-thrift" entry from ~/.claude.json manually.
```

---

## License

MIT © 2026 djproject-id
