#!/usr/bin/env bash
# lib/audit.sh: append-only audit log of token-thrift invocations.

_THRIFT_HOME="${THRIFT_HOME:-${HOME}/.token-thrift}"
_AUDIT_LOG="${_THRIFT_HOME}/audit.log"

audit_log() {
    local subcmd="${1:-?}"
    shift || true
    local args="$*"
    local cwd
    cwd=$(pwd 2>/dev/null || echo "?")
    local ts
    ts=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    local uid="${UID:-?}"
    mkdir -p "$_THRIFT_HOME" 2>/dev/null || true
    printf '%s | uid=%s | %s | %s | cwd=%s\n' \
        "$ts" "$uid" "$subcmd" "$args" "$cwd" >> "$_AUDIT_LOG" 2>/dev/null || true
    chmod 600 "$_AUDIT_LOG" 2>/dev/null || true
}

audit_show() {
    local n="${1:-50}"
    if [[ -f "$_AUDIT_LOG" ]]; then
        tail -n "$n" "$_AUDIT_LOG"
    else
        echo "(no audit log yet at $_AUDIT_LOG)"
    fi
}

audit_path() {
    echo "$_AUDIT_LOG"
}
