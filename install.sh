#!/usr/bin/env bash
# token-thrift installer
# Hardened wrapper for code-review-graph: hemat token, codebase aman.

set -euo pipefail

PKG_NAME="code-review-graph"
PKG_VERSION="2.3.2"
WHEEL_SHA256="08d715607aefde3414d28b3a7844243823b150dc63ba4dd4529d6919f540d048"

THRIFT_HOME="${HOME}/.token-thrift"
GLOBAL_IGNORE="${THRIFT_HOME}/global-ignore"
BIN_DIR="${HOME}/.local/bin"
WRAPPER="${BIN_DIR}/token-thrift"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WRAPPER_SRC="${SCRIPT_DIR}/token-thrift"
IGNORE_SRC="${SCRIPT_DIR}/global-ignore"

c_blue()   { printf '\033[1;34m%s\033[0m' "$*"; }
c_green()  { printf '\033[1;32m%s\033[0m' "$*"; }
c_yellow() { printf '\033[1;33m%s\033[0m' "$*"; }
c_red()    { printf '\033[1;31m%s\033[0m' "$*"; }

info() { printf '%s %s\n' "$(c_blue '[*]')" "$*"; }
ok()   { printf '%s %s\n' "$(c_green '[+]')" "$*"; }
warn() { printf '%s %s\n' "$(c_yellow '[!]')" "$*"; }
err()  { printf '%s %s\n' "$(c_red '[x]')" "$*" >&2; }

detect_os() {
    if [[ -d "/data/data/com.termux" ]]; then echo "termux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then echo "macos"
    else echo "linux"; fi
}

OS=$(detect_os)

check_python() {
    if ! command -v python3 >/dev/null 2>&1; then
        err "Python 3 tidak ditemukan."
        case "$OS" in
            termux) echo "  Run: pkg install python" ;;
            macos)  echo "  Run: brew install python" ;;
            linux)  echo "  Run: sudo apt install python3 python3-pip" ;;
        esac
        exit 1
    fi
    local pyver major minor
    pyver=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
    IFS=. read -r major minor <<<"$pyver"
    if [[ $major -lt 3 ]] || { [[ $major -eq 3 ]] && [[ $minor -lt 10 ]]; }; then
        err "Python 3.10+ dibutuhkan (ada $pyver)"
        exit 1
    fi
    ok "Python $pyver"
}

ensure_pipx() {
    if command -v pipx >/dev/null 2>&1; then
        ok "pipx siap"
        return
    fi
    info "Memasang pipx..."
    case "$OS" in
        termux) pkg install -y python-pip >/dev/null 2>&1 || true
                python3 -m pip install --user pipx ;;
        *)      python3 -m pip install --user pipx 2>/dev/null \
                    || python3 -m pip install --user --break-system-packages pipx ;;
    esac
    export PATH="$HOME/.local/bin:$PATH"
    if ! command -v pipx >/dev/null 2>&1; then
        err "pipx gagal terpasang"
        exit 1
    fi
    ok "pipx terpasang"
}

verify_sha256() {
    local file="$1" expected="$2" actual
    if command -v sha256sum >/dev/null 2>&1; then
        actual=$(sha256sum "$file" | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        actual=$(shasum -a 256 "$file" | awk '{print $1}')
    else
        actual=$(python3 -c "import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$file")
    fi
    [[ "$actual" == "$expected" ]]
}

download_verify_install() {
    local tmpdir wheel
    tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" RETURN

    info "Download $PKG_NAME==$PKG_VERSION (sebelum verifikasi SHA256)..."
    if ! python3 -m pip download --no-deps -d "$tmpdir" "${PKG_NAME}==${PKG_VERSION}" >/dev/null 2>&1; then
        err "Download gagal — cek koneksi internet"
        return 1
    fi
    wheel=$(find "$tmpdir" -maxdepth 1 -name "code_review_graph-${PKG_VERSION}-*.whl" | head -1)
    if [[ -z "$wheel" ]]; then
        err "Wheel tidak ditemukan dalam download"
        return 1
    fi

    info "Verifikasi SHA256..."
    if ! verify_sha256 "$wheel" "$WHEEL_SHA256"; then
        err "SHA256 TIDAK COCOK — wheel mungkin sudah diubah/MITM. Aborted."
        return 1
    fi
    ok "SHA256 cocok: $WHEEL_SHA256"

    info "Pasang dari wheel terverifikasi (isolated venv)..."
    pipx list 2>/dev/null | grep -q "$PKG_NAME" && pipx uninstall "$PKG_NAME" >/dev/null 2>&1 || true
    pipx install "$wheel" >/dev/null 2>&1 || pipx install "$wheel"
    ok "Terpasang isolated"
}

install_wrapper() {
    [[ -f "$WRAPPER_SRC" ]] || { err "$WRAPPER_SRC tidak ada"; return 1; }
    mkdir -p "$BIN_DIR"
    cp "$WRAPPER_SRC" "$WRAPPER"
    chmod +x "$WRAPPER"
    ok "Wrapper terpasang: $WRAPPER"
}

install_global_ignore() {
    [[ -f "$IGNORE_SRC" ]] || { err "$IGNORE_SRC tidak ada"; return 1; }
    mkdir -p "$THRIFT_HOME"
    cp "$IGNORE_SRC" "$GLOBAL_IGNORE"
    ok "Global ignore: $GLOBAL_IGNORE"
}

register_mcp() {
    info "Daftarkan MCP server ke Claude Code..."
    python3 - "$WRAPPER" <<'PYEOF'
import json, os, sys
wrapper = sys.argv[1]
path = os.path.expanduser("~/.claude.json")
config = {}
if os.path.exists(path):
    try:
        with open(path) as f: config = json.load(f)
    except Exception: config = {}
config.setdefault("mcpServers", {})
config["mcpServers"]["token-thrift"] = {"command": wrapper, "args": ["mcp-server"]}
with open(path, "w") as f: json.dump(config, f, indent=2)
print(f"  Registered di: {path}")
PYEOF
    ok "MCP server: token-thrift"
}

check_path() {
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        warn "$BIN_DIR belum ada di PATH"
        local rc
        case "$OS" in
            termux) rc="$HOME/.bashrc" ;;
            macos)  rc="$HOME/.zshrc" ;;
            *)      rc="$HOME/.bashrc" ;;
        esac
        if [[ -f "$rc" ]] && ! grep -q "/.local/bin" "$rc" 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
            ok "Ditambahkan ke $rc — restart shell atau: source $rc"
        else
            echo "  Tambahkan: export PATH=\"\$HOME/.local/bin:\$PATH\""
        fi
    fi
}

print_done() {
    echo
    echo "$(c_green '════════════════════════════════════════')"
    echo "$(c_green '  token-thrift terpasang')"
    echo "$(c_green '════════════════════════════════════════')"
    cat <<USAGE

  $(c_green 'Cara pakai:')
    token-thrift build              # parse codebase di project Anda
    token-thrift scan ~/myproject   # cek file sensitif
    token-thrift init ~/project     # tambah .code-review-graphignore
    token-thrift help               # daftar perintah

  $(c_green 'MCP server:') sudah terdaftar di ~/.claude.json
  Restart Claude Code agar tool aktif.

  $(c_yellow 'Tips:') jalankan 'token-thrift scan' di project Anda dulu sebelum 'build'.

USAGE
}

main() {
    info "Memulai instalasi token-thrift..."
    check_python
    ensure_pipx
    download_verify_install
    install_global_ignore
    install_wrapper
    register_mcp
    check_path
    print_done
}

main "$@"
