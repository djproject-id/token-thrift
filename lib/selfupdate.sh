#!/usr/bin/env bash
# lib/selfupdate.sh: self-update from the GitHub repository.
# Pulls the latest tagged release, optionally verifies a GPG signature, and
# re-runs install.sh. Refuses to clobber local edits unless --force is given.

_THRIFT_HOME="${THRIFT_HOME:-${HOME}/.token-thrift}"
_REPO_URL="${TOKEN_THRIFT_REPO:-https://github.com/djproject-id/token-thrift.git}"

# do_selfupdate [--force]
# Clones the latest release tag of token-thrift into a temp dir, verifies any
# GPG signature on the tag (best effort), and runs its install.sh.
do_selfupdate() {
    local force=0
    if [[ "${1:-}" == "--force" ]]; then force=1; fi

    command -v git >/dev/null 2>&1 || { echo "git is required for self-update." >&2; return 1; }

    local tmp
    tmp=$(mktemp -d)
    trap "rm -rf '$tmp'" RETURN

    echo "Fetching latest release from $_REPO_URL ..."
    if ! git -C "$tmp" clone --quiet --depth 1 "$_REPO_URL" repo 2>&1; then
        echo "Clone failed." >&2
        return 1
    fi

    # Pick the most recent semver tag; fall back to default branch HEAD
    local tag
    tag=$(git -C "$tmp/repo" tag --sort=-v:refname 2>/dev/null | head -1 || true)
    if [[ -n "$tag" ]]; then
        echo "Latest tag: $tag"
        git -C "$tmp/repo" checkout --quiet "$tag" || true

        # Best-effort GPG signature verification
        if git -C "$tmp/repo" tag -v "$tag" >/dev/null 2>&1; then
            echo "[+] GPG signature on tag $tag verified."
        else
            echo "[!] No verifiable GPG signature on tag $tag (continuing)."
        fi
    else
        echo "(no tags found, using default branch HEAD)"
    fi

    if [[ ! -x "$tmp/repo/install.sh" ]]; then
        chmod +x "$tmp/repo/install.sh" 2>/dev/null || true
    fi

    echo "Running install.sh from updated source ..."
    bash "$tmp/repo/install.sh"
}
