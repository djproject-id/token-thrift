#!/usr/bin/env bash
# lib/allowlist.sh: file-extension allowlist enforcement.
# Defense in depth on top of the danger-pattern denylist.

_THRIFT_HOME="${THRIFT_HOME:-${HOME}/.token-thrift}"
_ALLOWED_EXT_FILE="${_THRIFT_HOME}/data/allowed-extensions.txt"

_load_allowed_exts() {
    [[ -f "$_ALLOWED_EXT_FILE" ]] || return 1
    grep -vE '^[[:space:]]*(#|$)' "$_ALLOWED_EXT_FILE"
}

# scan_unknown_extensions <path>
# Prints a deduplicated list of file paths whose extension is not in the
# allowlist. Skips common build/cache dirs. Returns 1 if any unknown found.
scan_unknown_extensions() {
    local target="${1:-.}"
    target=$(cd "$target" 2>/dev/null && pwd) || return 2

    local allowed
    allowed=$(_load_allowed_exts | tr '[:upper:]' '[:lower:]')
    [[ -n "$allowed" ]] || return 0

    local unknown=()
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        case "$f" in
            */node_modules/*|*/.git/*|*/.venv/*|*/venv/*|*/target/*|*/dist/*|*/build/*|*/__pycache__/*|*/.cache/*|*/.next/*|*/.parcel-cache/*|*/.turbo/*) continue ;;
        esac
        local base ext
        base=$(basename "$f")
        # Files without a dot or starting with a dot (dotfiles) are skipped here
        # because they are usually handled by the danger pattern scanner instead.
        case "$base" in
            .*|*\.*) ;;
            *) continue ;;
        esac
        ext=".${base##*.}"
        ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
        if ! printf '%s\n' "$allowed" | grep -Fxq "$ext"; then
            unknown+=("${f#$target/}")
        fi
    done < <(find "$target" -type f 2>/dev/null)

    if [[ ${#unknown[@]} -gt 0 ]]; then
        printf '%s\n' "${unknown[@]}" | sort -u
        return 1
    fi
    return 0
}
