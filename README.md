# token-thrift

> Hemat token. Codebase Anda aman.

Hardened wrapper untuk [`code-review-graph`](https://github.com/tirth8205/code-review-graph) — knowledge graph code review tool dengan MCP integration. `token-thrift` membungkus tool aslinya supaya:

- **Cloud egress dimatikan otomatis** (paksa local-only mode)
- **Auto-block subcommand berbahaya** (`install`, `apply-refactor`, `cross-repo-search`)
- **Pre-flight scanner** menolak build kalau ada wallet/seed/key yang tidak ter-ignore
- **Global ignore template** otomatis kena ke setiap project (anti-lupa)
- **SHA256 verifikasi** wheel sebelum install — anti supply-chain
- **Isolated install** via pipx — tidak menyentuh Python global Anda
- **Tidak install hooks aggressive** ke editor / git Anda

Cocok untuk: repo trading bot, wallet utilities, codebase berisi private key, atau siapa saja yang paranoid soal supply-chain & data leakage.

## Quick Install

```bash
git clone https://github.com/<user>/token-thrift.git
cd token-thrift
bash install.sh
```

Itu satu-satunya perintah yang Anda butuh. Installer otomatis:

1. Cek Python 3.10+ tersedia
2. Install `pipx` kalau belum ada
3. Download wheel `code-review-graph==2.3.2` dari PyPI
4. **Verifikasi SHA256** sebelum install
5. Install isolated via pipx (tidak menyentuh Python global)
6. Pasang wrapper `token-thrift` ke `~/.local/bin/`
7. Pasang global ignore template ke `~/.token-thrift/global-ignore`
8. Daftarkan MCP server ke `~/.claude.json` (tanpa hooks)

Restart Claude Code → tool aktif.

## Pemakaian

```bash
token-thrift build              # parse codebase (cwd) + pre-flight scan
token-thrift scan ~/myproject   # cek file sensitif di project lain
token-thrift init ~/project     # pasang .code-review-graphignore default
token-thrift status             # cek status graph
token-thrift help               # daftar perintah
```

Subcommand `code-review-graph` lain tetap dilewatkan transparan — Anda bisa pakai `token-thrift query`, `token-thrift list-flows`, dll.

## Yang Diblokir

| Subcommand | Alasan |
|------------|--------|
| `install` | Auto-modifikasi `.gitignore`, `CLAUDE.md`, settings file, git hooks. Pakai installer ini saja. |
| `apply-refactor` | Tulis ke file source. Pakai editor Claude Code yang lebih aman. |
| `cross-repo-search` | Validasi registry minimal — potensi path traversal. |

## Pre-Flight Scanner

Sebelum `build` / `update`, scanner cek file matching:

- `*.key`, `*.pem`, `id_rsa*`, `id_ed25519*`
- `wallet*.json`, `keypair*.json`, `phantom*.json`, `solflare*.json`
- `.env`, `*.env`, `secrets.json`, `auth.json`, `credentials*`
- `*mnemonic*`, `*passphrase*`, `*seed.*`

Kalau ada match yang **belum** di-ignore, build **dihentikan**. User bisa override dengan ketik `i-accept-the-risk` (intentional friction).

## Multi-Device Setup

Copy folder `token-thrift` ke device kedua, jalankan `bash install.sh` ulang. Selesai. Tiap device punya install isolated sendiri.

## Verify Sendiri

Wheel SHA256 yang di-verify:

```
code_review_graph-2.3.2-py3-none-any.whl
SHA256: 08d715607aefde3414d28b3a7844243823b150dc63ba4dd4529d6919f540d048
```

Cek manual:
```bash
pip download --no-deps code-review-graph==2.3.2
sha256sum code_review_graph-2.3.2-py3-none-any.whl
```

## Uninstall

```bash
pipx uninstall code-review-graph
rm ~/.local/bin/token-thrift
rm -rf ~/.token-thrift
# Hapus entry "token-thrift" di ~/.claude.json secara manual
```

## License

MIT — sama dengan upstream `code-review-graph`.

## Threat Model

`token-thrift` melindungi dari:

- ✅ Supply-chain via PyPI (SHA256 verification)
- ✅ Cloud data leak (force unset env var)
- ✅ Aggressive auto-config (skip `install` subcommand)
- ✅ Wallet/seed file ter-index ke graph (pre-flight scanner)
- ✅ Cross-repo path traversal (block subcommand)
- ✅ System pollution (pipx isolated venv)

Tidak melindungi dari:

- ❌ Bug zero-day di tree-sitter / SQLite (gunakan dengan paranoid mindset)
- ❌ Kompromi `~/.claude.json` (jaga file ini)
- ❌ Kompromi pipx venv binary (re-install kalau ragu)
