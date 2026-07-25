#!/bin/bash
# Compare two GenAst Commit output directories (normalized).
# Usage:
#   genast-characterize.sh <baseline_dir> <candidate_dir>
# Exit 0 if identical after normalize; 1 on diff; 2 on usage error.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <baseline_dir> <candidate_dir>" >&2
  exit 2
fi

BASE="$1"
CAND="$2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NORM="$SCRIPT_DIR/genast-normalize.php"

if [[ ! -d "$BASE" || ! -d "$CAND" ]]; then
  echo "Both arguments must be directories" >&2
  exit 2
fi
if [[ ! -x "$NORM" && ! -f "$NORM" ]]; then
  echo "Missing $NORM" >&2
  exit 2
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/genast-char.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/base" "$TMP/cand"
php "$NORM" --dir "$BASE" "$TMP/base"
php "$NORM" --dir "$CAND" "$TMP/cand"

# Union of filenames present in either side
{
  (cd "$TMP/base" && ls -1)
  (cd "$TMP/cand" && ls -1)
} | sort -u > "$TMP/files"

rc=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  bf="$TMP/base/$f"
  cf="$TMP/cand/$f"
  if [[ ! -f "$bf" ]]; then
    echo "ONLY IN CANDIDATE: $f" >&2
    rc=1
    continue
  fi
  if [[ ! -f "$cf" ]]; then
    echo "ONLY IN BASELINE: $f" >&2
    rc=1
    continue
  fi
  if ! diff -u "$bf" "$cf" > "$TMP/diff.$f"; then
    echo "DIFF: $f" >&2
    cat "$TMP/diff.$f" >&2
    rc=1
  fi
done < "$TMP/files"

if [[ $rc -eq 0 ]]; then
  echo "OK: normalized outputs match"
fi
exit "$rc"
