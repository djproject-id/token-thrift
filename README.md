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
| 🌐 Cloud egress off by default | Cloud API env vars (OpenAI, Google, MiniMax) are unset at runtime. Your code never leaves your machine. |
| ✅ SHA256-verified install | The Python package wheel is hash-checked before installation. Anti supply-chain. |
| 📦 Isolated execution | Runs inside a pipx-managed virtualenv. Your global Python stays untouched. |
| 🚫 No aggressive hooks | Editor configs (.cursor, .windsurf, .zed) and git hooks are never modified. |
| 🛡️ Global ignore template | Ships with safe defaults for wallets, keys, secrets, and crypto artifacts. |

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
3. Verify the SHA256 of the package wheel before installing.
4. Install the engine inside an isolated pipx venv.
5. Drop the `token-thrift` wrapper into `~/.local/bin/`.
6. Place the global ignore template at `~/.token-thrift/global-ignore`.
7. Register the MCP server in `~/.claude.json`.

Restart Claude Code and the tool is active.

---

## Usage

```bash
token-thrift build              # Parse the codebase in cwd, after a pre-flight scan.
token-thrift scan ~/myproject   # Scan a directory for sensitive files.
token-thrift init ~/myproject   # Drop the default ignore template into a project.
token-thrift status             # Show graph status.
token-thrift help               # Full command list.
```

Other subcommands pass through transparently, but always under the security guardrails described below.

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

---

## Threat Model

token-thrift protects against:

- ✅ Supply-chain attacks (SHA256 verification on every install).
- ✅ Cloud data leakage (cloud env vars are forcibly unset at runtime).
- ✅ Aggressive auto-config (dangerous subcommands are blocked).
- ✅ Wallet or seed files indexed by mistake (pre-flight scanner).
- ✅ Cross-repo path traversal (`cross-repo-search` is blocked).
- ✅ Global Python pollution (pipx-isolated venv).

token-thrift does NOT protect against:

- ❌ Zero-day bugs in the parser or SQLite. Run with a paranoid mindset.
- ❌ Compromise of `~/.claude.json`. Guard this file.
- ❌ Compromise of the pipx venv binary. Reinstall if in doubt.

---

## Multi-Device Setup

Clone the repo on the second device, run `bash install.sh`. Each device gets its own isolated install.

---

## Verify Yourself

The wheel SHA256 verified at install time:

```
08d715607aefde3414d28b3a7844243823b150dc63ba4dd4529d6919f540d048
```

Verify manually:
```bash
pip download --no-deps code-review-graph==2.3.2
sha256sum code_review_graph-2.3.2-py3-none-any.whl
```

---

## Architecture

token-thrift consists of:

- `install.sh`: Verified installer with SHA256 checks, pipx isolation, and MCP registration.
- `token-thrift`: Bash wrapper that adds the pre-flight scanner, env-var hardening, and subcommand guards.
- `global-ignore`: Defensive ignore template for wallets, keys, and crypto artifacts.

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
