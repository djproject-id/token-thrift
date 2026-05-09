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

python3 -m pip install --quiet setuptools wheel 2>/dev/null \
    || python3 -m pip install --user --quiet setuptools wheel 2>/dev/null \
    || python3 -m pip install --break-system-packages --quiet setuptools wheel 2>/dev/null \
    || true

if ! python3 -m pip download "$PKG" -d "$TMPDIR" --only-binary :all: 2>&1 | tail -5; then
    echo "Falling back to allow sdist for some packages..."
    rm -rf "$TMPDIR"/*
    python3 -m pip download "$PKG" -d "$TMPDIR" 2>&1 | tail -5 \
        || { echo "pip download failed in both modes."; exit 1; }
fi

echo
echo "Downloaded files:"
ls -1 "$TMPDIR"

# Format the lock file via Python for reliable parsing of package/version
# pairs from wheel and sdist filenames.
python3 - "$TMPDIR" "$LOCK_FILE" "$(uname -sm)" <<'PYEOF'
import hashlib
import os
import re
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

src_dir = Path(sys.argv[1])
lock_path = Path(sys.argv[2])
platform = sys.argv[3]


def parse(name: str):
    """Return (pep503_name, version) or (None, None) if not a known artifact."""
    # PEP 427 wheel: {name}-{version}(-{build})?-{python}-{abi}-{platform}.whl
    m = re.match(
        r"^(?P<n>[A-Za-z0-9_.]+?)-(?P<v>[0-9][^-]*?)(-\d[^-]*)?-(?P<py>\w+)-(?P<abi>\w+)-(?P<plat>[\w_.+]+)\.whl$",
        name,
    )
    if m:
        return m.group("n").replace("_", "-").lower(), m.group("v")
    # Sdist: {name}-{version}.tar.gz where name may contain hyphens.
    m = re.match(r"^(?P<n>[A-Za-z0-9_.][A-Za-z0-9_.-]*?)-(?P<v>[0-9][^-]*)\.tar\.gz$", name)
    if m:
        return m.group("n").lower(), m.group("v")
    return None, None


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


groups: dict[tuple[str, str], list[tuple[str, str]]] = defaultdict(list)
unparsed: list[str] = []

for f in sorted(src_dir.iterdir()):
    pkg, ver = parse(f.name)
    if pkg is None:
        unparsed.append(f.name)
        continue
    groups[(pkg, ver)].append((sha256(f), f.name))

if unparsed:
    print(f"WARNING: could not parse: {unparsed}", file=sys.stderr)

now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
lines = [
    "# token-thrift requirements lock",
    f"# Generated {now} on {platform}",
    "# Reproduce: bash scripts/gen-lock.sh",
    "# Verify:    pip install --require-hashes -r requirements.lock",
    "#",
    "# This lock pins every transitive dependency. If any wheel on PyPI is",
    "# altered, install will fail with a hash mismatch instead of silently",
    "# pulling tampered code. Lock files are platform-specific (wheels include",
    "# arch tags), so regenerate on each target system.",
    "",
]

for (pkg, ver), files in sorted(groups.items()):
    lines.append(f"{pkg}=={ver} \\")
    last_idx = len(files) - 1
    for i, (h, fname) in enumerate(files):
        sep = " \\" if i < last_idx else ""
        lines.append(f"    --hash=sha256:{h}{sep}")
    lines.append(f"    # files: {', '.join(f for _, f in files)}")
    lines.append("")

lock_path.write_text("\n".join(lines))
print(f"Lock file written: {lock_path}")
print(f"Pinned {len(groups)} packages, {sum(len(v) for v in groups.values())} files")
PYEOF

echo
echo "Quick sanity check:"
grep -c "^==" "$LOCK_FILE" 2>/dev/null || true
grep -cE "^[a-zA-Z][a-zA-Z0-9._-]*==" "$LOCK_FILE" 2>/dev/null
echo "package entries"
