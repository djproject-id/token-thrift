#!/usr/bin/env bash
# lib/integrity.sh: tamper-evident hash storage and verification.
# Sourced by install.sh (to record hashes) and token-thrift wrapper (to verify).

_THRIFT_HOME="${THRIFT_HOME:-${HOME}/.token-thrift}"

_compute_sha256() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        python3 -c "import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$file"
    fi
}

# Wrapper integrity =====================================================

store_wrapper_hash() {
    local wrapper="$1"
    local out="${_THRIFT_HOME}/wrapper.sha256"
    mkdir -p "$_THRIFT_HOME"
    _compute_sha256 "$wrapper" > "$out"
    chmod 600 "$out"
}

verify_wrapper_integrity() {
    local wrapper="$1"
    local stored_file="${_THRIFT_HOME}/wrapper.sha256"
    [[ -f "$stored_file" ]] || return 0
    local stored actual
    stored=$(cat "$stored_file")
    actual=$(_compute_sha256 "$wrapper")
    [[ "$stored" == "$actual" ]] || return 1
    return 0
}

# MCP config integrity =================================================

store_mcp_hash() {
    local mcp_file="${1:-${HOME}/.claude.json}"
    local out="${_THRIFT_HOME}/claude.json.sha256"
    mkdir -p "$_THRIFT_HOME"
    if [[ -f "$mcp_file" ]]; then
        _compute_sha256 "$mcp_file" > "$out"
        chmod 600 "$out"
    fi
}

verify_mcp_integrity() {
    local mcp_file="${1:-${HOME}/.claude.json}"
    local stored_file="${_THRIFT_HOME}/claude.json.sha256"
    [[ -f "$stored_file" ]] || return 0
    [[ -f "$mcp_file" ]] || return 0
    local stored actual
    stored=$(cat "$stored_file")
    actual=$(_compute_sha256 "$mcp_file")
    [[ "$stored" == "$actual" ]] || return 1
    return 0
}

# Pipx venv integrity ==================================================

snapshot_pipx_venv() {
    local pkg="${1:-code-review-graph}"
    local out="${_THRIFT_HOME}/pipx-venv.sha256"
    local venv
    for v in "$HOME/.local/share/pipx/venvs/$pkg" \
             "$HOME/.local/pipx/venvs/$pkg" \
             "$HOME/Library/Application Support/pipx/venvs/$pkg"; do
        if [[ -d "$v" ]]; then venv="$v"; break; fi
    done
    [[ -n "${venv:-}" ]] || return 1

    mkdir -p "$_THRIFT_HOME"
    find "$venv/bin" -type f 2>/dev/null \
        | sort \
        | while read -r f; do
            printf '%s  %s\n' "$(_compute_sha256 "$f")" "${f#$venv/}"
          done > "$out"
    chmod 600 "$out"
}

verify_pipx_venv() {
    local pkg="${1:-code-review-graph}"
    local snapshot="${_THRIFT_HOME}/pipx-venv.sha256"
    [[ -f "$snapshot" ]] || return 0
    local venv
    for v in "$HOME/.local/share/pipx/venvs/$pkg" \
             "$HOME/.local/pipx/venvs/$pkg" \
             "$HOME/Library/Application Support/pipx/venvs/$pkg"; do
        if [[ -d "$v" ]]; then venv="$v"; break; fi
    done
    [[ -n "${venv:-}" ]] || return 1

    local rel expected actual fail=0
    while read -r expected rel; do
        local f="$venv/$rel"
        if [[ ! -f "$f" ]]; then fail=1; continue; fi
        actual=$(_compute_sha256 "$f")
        [[ "$actual" == "$expected" ]] || fail=1
    done < "$snapshot"
    return $fail
}
