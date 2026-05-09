#!/usr/bin/env bash
# lib/backup.sh: encrypted backup and restore of token-thrift state.
# Encrypts ~/.token-thrift/ and any local .code-review-graph/ directories.

_THRIFT_HOME="${THRIFT_HOME:-${HOME}/.token-thrift}"

_pick_crypto() {
    if command -v age >/dev/null 2>&1; then
        echo "age"
    elif command -v gpg >/dev/null 2>&1; then
        echo "gpg"
    elif command -v openssl >/dev/null 2>&1; then
        echo "openssl"
    else
        echo ""
    fi
}

# do_backup <output-archive>
# Tar + encrypt ~/.token-thrift/ to the given path. Prompts for passphrase.
do_backup() {
    local out="${1:-token-thrift-backup-$(date +%Y%m%d-%H%M%S).age}"
    local tool
    tool=$(_pick_crypto)
    [[ -n "$tool" ]] || { echo "Need one of: age, gpg, openssl. Install one and retry." >&2; return 1; }

    local tar_tmp
    tar_tmp=$(mktemp)
    trap "rm -f '$tar_tmp'" RETURN

    echo "Archiving ~/.token-thrift/ ..."
    if ! tar -cf "$tar_tmp" -C "$HOME" .token-thrift 2>/dev/null; then
        echo "tar failed (is ~/.token-thrift/ present?)" >&2
        return 1
    fi

    case "$tool" in
        age)
            age --passphrase --output "$out" "$tar_tmp"
            ;;
        gpg)
            gpg --symmetric --cipher-algo AES256 --output "$out" "$tar_tmp"
            ;;
        openssl)
            openssl enc -aes-256-cbc -salt -pbkdf2 -in "$tar_tmp" -out "$out"
            ;;
    esac
    chmod 600 "$out"
    echo "Backup written to $out (encrypted with $tool)"
}

# do_restore <input-archive>
# Decrypt and extract a backup created by do_backup. Prompts for passphrase.
do_restore() {
    local in="${1:?usage: token-thrift restore <archive>}"
    [[ -f "$in" ]] || { echo "Archive not found: $in" >&2; return 1; }
    local tool
    tool=$(_pick_crypto)
    [[ -n "$tool" ]] || { echo "Need one of: age, gpg, openssl." >&2; return 1; }

    local tar_tmp
    tar_tmp=$(mktemp)
    trap "rm -f '$tar_tmp'" RETURN

    case "$in" in
        *.age)        age --decrypt --output "$tar_tmp" "$in" || return 1 ;;
        *.gpg|*.asc)  gpg --decrypt --output "$tar_tmp" "$in" || return 1 ;;
        *.enc|*.aes)  openssl enc -d -aes-256-cbc -pbkdf2 -in "$in" -out "$tar_tmp" || return 1 ;;
        *)
            case "$tool" in
                age)     age --decrypt --output "$tar_tmp" "$in" ;;
                gpg)     gpg --decrypt --output "$tar_tmp" "$in" ;;
                openssl) openssl enc -d -aes-256-cbc -pbkdf2 -in "$in" -out "$tar_tmp" ;;
            esac || return 1
            ;;
    esac

    echo "Restoring to \$HOME (will overwrite ~/.token-thrift/) ..."
    tar -xf "$tar_tmp" -C "$HOME"
    echo "Restore complete."
}
