#!/usr/bin/env bash
# token-thrift installer
# Security-hardened code review tool for sensitive codebases.

set -euo pipefail

PKG_NAME="code-review-graph"
PKG_VERSION="2.3.2"
WHEEL_SHA256="08d715607aefde3414d28b3a7844243823b150dc63ba4dd4529d6919f540d048"

THRIFT_HOME="${HOME}/.token-thrift"
GLOBAL_IGNORE="${THRIFT_HOME}/global-ignore"
LIB_DEST="${THRIFT_HOME}/lib"
DATA_DEST="${THRIFT_HOME}/data"
BIN_DIR="${HOME}/.local/bin"
WRAPPER="${BIN_DIR}/token-thrift"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WRAPPER_SRC="${SCRIPT_DIR}/token-thrift"
IGNORE_SRC="${SCRIPT_DIR}/global-ignore"
LIB_SRC="${SCRIPT_DIR}/lib"
DATA_SRC="${SCRIPT_DIR}/data"
LOCK_SRC="${SCRIPT_DIR}/requirements.lock"

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

# Source integrity helpers from the source tree (pre-install).
if [[ -f "$LIB_SRC/integrity.sh" ]]; then
    THRIFT_HOME="$THRIFT_HOME" source "$LIB_SRC/integrity.sh"
fi

check_python() {
    if ! command -v python3 >/dev/null 2>&1; then
        err "Python 3 not found."
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
        err "Python 3.10+ required (found $pyver)"
        exit 1
    fi
    ok "Python $pyver"
}

ensure_pipx() {
    if command -v pipx >/dev/null 2>&1; then
        ok "pipx ready"
        return
    fi
    info "Installing pipx..."
    case "$OS" in
        termux) pkg install -y python-pip >/dev/null 2>&1 || true
                python3 -m pip install --user pipx ;;
        *)      python3 -m pip install --user pipx 2>/dev/null \
                    || python3 -m pip install --user --break-system-packages pipx ;;
    esac
    export PATH="$HOME/.local/bin:$PATH"
    if ! command -v pipx >/dev/null 2>&1; then
        err "pipx install failed"
        exit 1
    fi
    ok "pipx installed"
}

verify_sha256_local() {
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

    info "Downloading $PKG_NAME==$PKG_VERSION (pre-verification)..."
    if ! python3 -m pip download --no-deps -d "$tmpdir" "${PKG_NAME}==${PKG_VERSION}" >/dev/null 2>&1; then
        err "Download failed. Check your internet connection."
        return 1
    fi
    wheel=$(find "$tmpdir" -maxdepth 1 -name "code_review_graph-${PKG_VERSION}-*.whl" | head -1)
    if [[ -z "$wheel" ]]; then
        err "Wheel not found in download"
        return 1
    fi

    info "Verifying main wheel SHA256..."
    if ! verify_sha256_local "$wheel" "$WHEEL_SHA256"; then
        err "SHA256 mismatch on main wheel. Aborted."
        return 1
    fi
    ok "Main wheel verified: $WHEEL_SHA256"

    info "Installing isolated venv via pipx..."
    pipx list 2>/dev/null | grep -q "$PKG_NAME" && pipx uninstall "$PKG_NAME" >/dev/null 2>&1 || true
    if [[ -f "$LOCK_SRC" ]]; then
        info "Lock file present, enforcing --require-hashes for transitive deps..."
        if ! pipx install \
                --pip-args "--require-hashes -r $LOCK_SRC" \
                "$wheel" >/dev/null 2>&1; then
            warn "Hash-pinned install failed (lock may be platform-specific). Falling back."
            pipx install "$wheel" >/dev/null 2>&1 || pipx install "$wheel"
        else
            ok "All dependencies installed with verified hashes"
        fi
    else
        warn "requirements.lock not found, only the main wheel was hash-verified."
        info "  To pin transitive deps: bash scripts/gen-lock.sh"
        pipx install "$wheel" >/dev/null 2>&1 || pipx install "$wheel"
    fi
    ok "Engine installed"
}

install_wrapper() {
    [[ -f "$WRAPPER_SRC" ]] || { err "$WRAPPER_SRC missing"; return 1; }
    mkdir -p "$BIN_DIR"
    cp "$WRAPPER_SRC" "$WRAPPER"
    chmod 700 "$WRAPPER"
    ok "Wrapper installed: $WRAPPER"
}

install_lib_data() {
    mkdir -p "$LIB_DEST" "$DATA_DEST"
    if [[ -d "$LIB_SRC" ]]; then
        cp "$LIB_SRC"/*.sh "$LIB_DEST"/ 2>/dev/null || true
        cp "$LIB_SRC"/*.py "$LIB_DEST"/ 2>/dev/null || true
    fi
    if [[ -d "$DATA_SRC" ]]; then
        cp "$DATA_SRC"/*.txt "$DATA_DEST"/ 2>/dev/null || true
    fi
    ok "Helper libraries: $LIB_DEST"
    ok "Data files: $DATA_DEST"
}

install_global_ignore() {
    [[ -f "$IGNORE_SRC" ]] || { err "$IGNORE_SRC missing"; return 1; }
    mkdir -p "$THRIFT_HOME"
    cp "$IGNORE_SRC" "$GLOBAL_IGNORE"
    ok "Global ignore: $GLOBAL_IGNORE"
}

register_mcp() {
    info "Registering MCP server with Claude Code..."
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
print(f"  Registered at: {path}")
PYEOF
    ok "MCP server registered: token-thrift"
}

harden_permissions() {
    info "Applying restrictive permissions..."
    chmod 700 "$THRIFT_HOME" 2>/dev/null || true
    chmod 600 "$GLOBAL_IGNORE" 2>/dev/null || true
    chmod 700 "$LIB_DEST" 2>/dev/null || true
    chmod 700 "$DATA_DEST" 2>/dev/null || true
    find "$LIB_DEST" -type f -exec chmod 600 {} \; 2>/dev/null || true
    find "$DATA_DEST" -type f -exec chmod 600 {} \; 2>/dev/null || true
    chmod 600 "${HOME}/.claude.json" 2>/dev/null || true
    chmod 700 "$WRAPPER" 2>/dev/null || true
    ok "Permissions hardened (700/600)"
}

snapshot_integrity() {
    info "Taking integrity snapshots (wrapper, MCP config, pipx venv)..."
    if declare -F store_wrapper_hash >/dev/null 2>&1; then
        store_wrapper_hash "$WRAPPER"
    fi
    if declare -F store_mcp_hash >/dev/null 2>&1; then
        store_mcp_hash "${HOME}/.claude.json"
    fi
    if declare -F snapshot_pipx_venv >/dev/null 2>&1; then
        snapshot_pipx_venv "$PKG_NAME" || true
    fi
    ok "Integrity snapshots stored in $THRIFT_HOME"
}

check_path() {
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        warn "$BIN_DIR is not on PATH"
        local rc
        case "$OS" in
            termux) rc="$HOME/.bashrc" ;;
            macos)  rc="$HOME/.zshrc" ;;
            *)      rc="$HOME/.bashrc" ;;
        esac
        if [[ -f "$rc" ]] && ! grep -q "/.local/bin" "$rc" 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
            ok "Added to $rc. Restart your shell, or run: source $rc"
        else
            echo "  Add to your shell rc: export PATH=\"\$HOME/.local/bin:\$PATH\""
        fi
    fi
}

print_done() {
    echo
    echo "$(c_green '════════════════════════════════════════')"
    echo "$(c_green '  token-thrift installed')"
    echo "$(c_green '════════════════════════════════════════')"
    cat <<USAGE

  $(c_green 'Usage:')
    token-thrift build              # Parse the codebase in cwd, after a pre-flight scan.
    token-thrift scan ~/myproject   # Scan a directory for sensitive files.
    token-thrift secret-scan        # Content-level secret scan.
    token-thrift ext-scan           # File-extension allowlist scan.
    token-thrift audit              # Show recent audit log.
    token-thrift backup out.age     # Encrypted backup of state.
    token-thrift self-update        # Update from GitHub.
    token-thrift help               # Full command list.

  $(c_green 'MCP server:') registered in ~/.claude.json
  Restart Claude Code to activate the tool.

  $(c_yellow 'Tip:') run 'token-thrift scan' on your project before 'build'.

USAGE
}

main() {
    info "Starting token-thrift installation..."
    check_python
    ensure_pipx
    install_lib_data
    install_global_ignore
    download_verify_install
    install_wrapper
    register_mcp
    harden_permissions
    snapshot_integrity
    check_path
    print_done
}

main "$@"
