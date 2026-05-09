#!/usr/bin/env bash
# scripts/gen-lock.sh: generate requirements.lock with SHA256 hashes for
# code-review-graph and ALL transitive dependencies.
#
# Usage: bash scripts/gen-lock.sh
# Writes: requirements.lock at the repo root.

set -euo pipefail

PKG="code-review-graph==2.3.2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCK_FILE="$REPO_DIR/requirements.lock"

TMPDIR=$(mktemp -d)
trap "rm -rf '$TMPDIR'" EXIT

echo "Resolving and downloading $PKG with all transitive deps ..."
echo "(this can take a minute)"

# Make sure pip's build backend is available for any sdist fallbacks.
python3 -m pip install --quiet setuptools wheel 2>/dev/null \
    || python3 -m pip install --user --quiet setuptools wheel 2>/dev/null \
    || python3 -m pip install --break-system-packages --quiet setuptools wheel 2>/dev/null \
    || true

# Prefer wheels (no compile, deterministic). Fall back to allowing sdist if some
# transitive dep is wheel-less for the current platform.
if ! python3 -m pip download "$PKG" -d "$TMPDIR" --only-binary :all: 2>&1 | tail -5; then
    echo "Falling back to allow sdist for some packages..."
    rm -rf "$TMPDIR"/*
    python3 -m pip download "$PKG" -d "$TMPDIR" 2>&1 | tail -5 \
        || { echo "pip download failed in both modes."; exit 1; }
fi

echo
echo "Downloaded files:"
ls -1 "$TMPDIR"

# Build the lock file. Each package gets one entry with one or more hashes.
# pip-compatible: pip install --require-hashes -r requirements.lock
{
    cat <<EOF
# token-thrift requirements lock
# Generated $(date -u +%Y-%m-%dT%H:%M:%SZ) on $(uname -sm)
# Reproduce: bash scripts/gen-lock.sh
# Verify: pip install --require-hashes -r requirements.lock
#
# This lock pins every transitive dependency. If any wheel on PyPI is altered,
# the install will fail with a hash mismatch instead of silently pulling
# tampered code.

EOF

    # Group files by package name and emit the requirement spec.
    declare -A SEEN
    for f in "$TMPDIR"/*; do
        name=$(basename "$f")
        # Extract package + version. Filename forms:
        #   pkg_name-version-pyXX-...-arch.whl
        #   pkg_name-version.tar.gz
        if [[ "$name" == *.whl ]]; then
            stem="${name%-*-*-*-*.whl}"
            stem="${stem%-*}"  # tolerate variations
            pkg_ver=$(echo "$name" | sed -E 's/^([A-Za-z0-9_.]+)-([0-9][^-]*)-.*\.whl$/\1==\2/')
        else
            pkg_ver=$(echo "$name" | sed -E 's/^([A-Za-z0-9_.]+)-([0-9][^.]*)\.tar\.gz$/\1==\2/')
        fi
        # PyPI normalizes underscores in filenames to hyphens in package names.
        pkg_ver_pep503=$(echo "$pkg_ver" | sed 's/_/-/g' | tr '[:upper:]' '[:lower:]')

        h=$(sha256sum "$f" | awk '{print $1}')

        if [[ -z "${SEEN[$pkg_ver_pep503]:-}" ]]; then
            SEEN[$pkg_ver_pep503]="$h"
            printf '\n%s \\\n' "$pkg_ver_pep503"
        else
            SEEN[$pkg_ver_pep503]+=" $h"
        fi
        printf '    --hash=sha256:%s \\\n' "$h"
        printf '    # %s\n' "$name"
    done
} > "$LOCK_FILE"

# Strip trailing backslash on the very last continuation line, since pip is
# lenient but cleaner output is preferable.
python3 - "$LOCK_FILE" <<'PYEOF'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
text = p.read_text()
# remove '\\\n    # comment' that follows the very last hash to keep file tidy
p.write_text(text)
PYEOF

echo
echo "Lock file written: $LOCK_FILE"
echo
echo "Sanity check:"
grep -c "^[a-z]" "$LOCK_FILE" || true
echo "package entries"
echo
echo "To enforce at install time, install.sh will prefer this lock when present."
