<div align="center">

# token-thrift

**Hemat token. Codebase Anda aman.**

Smart, token-efficient code review tool dengan **security hardening built-in** — dirancang untuk codebase yang berisi wallet, private key, dan secret yang harus dilindungi.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-linux%20%7C%20macos%20%7C%20termux-blue?style=flat-square)](#)
[![Python](https://img.shields.io/badge/python-3.10%2B-blue?style=flat-square)](#)

</div>

---

## Kenapa token-thrift?

AI coding assistant (Claude Code, Cursor, dll) sering re-read seluruh codebase setiap task — **token kebakar percuma**. token-thrift pakai knowledge graph supaya AI cuma baca code yang relevan. Hasil: **6.8×–49× fewer tokens**.

Tapi yang lebih penting — token-thrift **dirancang untuk codebase sensitif**:

| Fitur | Apa Manfaatnya |
|-------|----------------|
| 🔒 **Pre-flight scanner** | Auto-deteksi `*.key`, `wallet*.json`, `.env`, `*mnemonic*` — refuse build kalau belum di-ignore |
| 🌐 **Cloud egress off by default** | Code Anda **tidak meninggalkan mesin** — semua env var cloud (OpenAI/Google/MiniMax) di-unset paksa |
| ✅ **SHA256-verified install** | Anti supply-chain — wheel diverifikasi sebelum dipasang |
| 📦 **Isolated execution** | Jalan di pipx venv terpisah — tidak menyentuh Python global Anda |
| 🚫 **No aggressive hooks** | Editor config & git hooks Anda tidak diutak-atik |
| 🛡️ **Global ignore template** | Safe default untuk pattern wallet, key, dan secret common |

Cocok untuk: **trading bot**, wallet utility, project dengan `.env` secrets, atau siapa saja yang paranoid soal data leakage & supply-chain.

---

## Quick Install

```bash
git clone https://github.com/djproject-id/token-thrift.git
cd token-thrift
bash install.sh
```

Satu perintah. Installer otomatis akan:

1. Cek Python 3.10+ tersedia
2. Pasang `pipx` kalau belum ada
3. **Verifikasi SHA256** package sebelum install
4. Install isolated (tidak menyentuh Python global)
5. Pasang wrapper `token-thrift` ke `~/.local/bin/`
6. Pasang global ignore template ke `~/.token-thrift/`
7. Daftarkan MCP server ke `~/.claude.json`

Restart Claude Code → tool aktif.

---

## Pemakaian

```bash
token-thrift build              # parse codebase (cwd) + pre-flight scan
token-thrift scan ~/myproject   # cek file sensitif di project lain
token-thrift init ~/project     # pasang .code-review-graphignore default
token-thrift status             # cek status graph
token-thrift help               # daftar perintah lengkap
```

Subcommand lain dilewatkan transparan — `token-thrift query`, `token-thrift list-flows`, dll tetap bekerja seperti biasa, tapi dalam mode safe.

---

## Yang Diblokir (For Your Safety)

| Subcommand | Alasan Diblokir |
|------------|-----------------|
| `install` | Auto-modifikasi banyak system file (settings, git hooks). Pakai installer ini saja. |
| `apply-refactor` | Tulis langsung ke source code. Pakai editor Claude Code yang lebih aman. |
| `cross-repo-search` | Validasi registry minimal — potensi path traversal di `~/.code-review-graph/registry.json`. |

---

## Pre-Flight Scanner

Sebelum `build` / `update`, scanner cek file matching:

```
*.key, *.pem, id_rsa*, id_ed25519*, *.gpg
wallet*.json, keypair*.json, phantom*.json, solflare*.json, backpack*.json
.env, *.env, secrets.json, auth.json, credentials*
*mnemonic*, *passphrase*, *seed.json, *master.key
```

Kalau ada match yang **belum** di-ignore di `.code-review-graphignore`, build **dihentikan**. Override hanya dengan ketik `i-accept-the-risk` — intentional friction supaya tidak ada accident.

---

## Threat Model

token-thrift melindungi dari:

- ✅ Supply-chain attack (SHA256 verification setiap install)
- ✅ Cloud data leak (force-unset cloud env vars at runtime)
- ✅ Aggressive auto-config (block dangerous subcommands)
- ✅ Wallet/seed file ter-index ke graph (pre-flight scanner)
- ✅ Cross-repo path traversal (block `cross-repo-search`)
- ✅ Python global pollution (pipx isolated venv)

Tidak melindungi dari:

- ❌ Bug zero-day di parser/SQLite — paranoid mindset wajib
- ❌ Kompromi `~/.claude.json` — jaga file ini
- ❌ Kompromi pipx venv — re-install kalau ragu

---

## Multi-Device Setup

Clone repo di device kedua, jalankan `bash install.sh`. Tiap device punya install isolated sendiri.

---

## Verify Yourself

SHA256 wheel yang di-verify saat install:

```
08d715607aefde3414d28b3a7844243823b150dc63ba4dd4529d6919f540d048
```

Cek manual:
```bash
pip download --no-deps code-review-graph==2.3.2
sha256sum code_review_graph-2.3.2-py3-none-any.whl
```

---

## Architecture

token-thrift terdiri dari:

- **`install.sh`** — verified installer dengan SHA256 check, pipx isolation, MCP registration
- **`token-thrift`** — bash wrapper dengan pre-flight scanner, env-var hardening, dan subcommand guards
- **`global-ignore`** — defensive ignore template untuk wallet, key, dan crypto artifact patterns

Engine knowledge graph: [`code-review-graph`](https://pypi.org/project/code-review-graph/) (PyPI) — di-pin ke versi `2.3.2` dengan SHA256 verification.

Integrasi AI: MCP (Model Context Protocol) — kompatibel dengan Claude Code dan editor lain yang support MCP.

---

## Uninstall

```bash
pipx uninstall code-review-graph
rm ~/.local/bin/token-thrift
rm -rf ~/.token-thrift
# Hapus entry "token-thrift" di ~/.claude.json (manual)
```

---

## License

MIT © 2026 djproject-id
