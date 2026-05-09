#!/usr/bin/env bash
# lib/secret-scan.sh: content-level secret scanner.
# Greps text files for inline secrets (private keys, API tokens, mnemonics).
# Complements the filename-based pre-flight scanner.

_THRIFT_HOME="${THRIFT_HOME:-${HOME}/.token-thrift}"
_PATTERNS_FILE="${_THRIFT_HOME}/data/secret-patterns.txt"

# scan_content_secrets <path>
# Walks the path, applies each regex from secret-patterns.txt to every text file
# under 1 MB. Prints "<rel-path>:<line-no>:<matched-snippet>" for each hit.
# Returns 1 if any hit, 0 if clean.
scan_content_secrets() {
    local target="${1:-.}"
    target=$(cd "$target" 2>/dev/null && pwd) || return 2
    [[ -f "$_PATTERNS_FILE" ]] || { echo "(secret-patterns.txt missing)"; return 2; }

    local hits=0
    local pattern
    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue
        case "$pattern" in
            \#*) continue ;;
        esac
        # find candidate text files under 1MB; let grep handle binary detection
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            case "$f" in
                */node_modules/*|*/.git/*|*/.venv/*|*/venv/*|*/target/*|*/dist/*|*/build/*|*/__pycache__/*|*/.cache/*) continue ;;
            esac
            # grep returns 0 if matched, nonzero otherwise; -I skips binary
            if grep -InE -- "$pattern" "$f" 2>/dev/null | head -3 > /tmp/.tt-secret.$$ && [[ -s /tmp/.tt-secret.$$ ]]; then
                while IFS= read -r line; do
                    printf '  %s: %s\n' "${f#$target/}" "$line"
                done < /tmp/.tt-secret.$$
                hits=1
            fi
            rm -f /tmp/.tt-secret.$$
        done < <(find "$target" -type f -size -1M 2>/dev/null)
    done < "$_PATTERNS_FILE"

    return $hits
}
