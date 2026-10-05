#!/usr/bin/env bash
# Print a git tree hash of the working tree (tracked + untracked, .gitignore respected)
# without touching the user's index or HEAD. Compare two snapshots with `git diff <a> <b>`.
set -euo pipefail
idx=$(mktemp)
trap 'rm -f "$idx"' EXIT
cp "$(git rev-parse --git-dir)/index" "$idx" 2>/dev/null || true
GIT_INDEX_FILE="$idx" git add -A
GIT_INDEX_FILE="$idx" git write-tree
