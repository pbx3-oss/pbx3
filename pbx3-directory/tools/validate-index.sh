#!/usr/bin/env bash
# Validate catalog/instance-index.json against schema (basic jq checks; optional python jsonschema).
#
# Usage:
#   ./validate-index.sh path/to/instance-index.json
#   ./validate-index.sh   # validates ../schema/instance-index.json

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FILE="${1:-$ROOT/schema/instance-index.json}"

if ! command -v jq >/dev/null 2>&1; then
  echo "validate-index: jq required" >&2
  exit 1
fi

[[ -f "$FILE" ]] || { echo "File not found: $FILE" >&2; exit 1; }

jq -e '.version and .updated_at and (.instances | type == "array")' "$FILE" >/dev/null

errors=0
while IFS= read -r line; do
  echo "ERROR: $line" >&2
  errors=$((errors + 1))
done < <(jq -r '
  .instances[]
  | select(.id == null or .id == "")
  | "instance missing id"
' "$FILE")

while IFS= read -r line; do
  echo "ERROR: $line" >&2
  errors=$((errors + 1))
done < <(jq -r '
  .instances[]
  | select(.api_base_url == null or .api_base_url == "")
  | "instance \(.id // "?") missing api_base_url"
' "$FILE")

# duplicate ids
dupes=$(jq -r '[.instances[].id] | group_by(.) | map(select(length > 1)) | length' "$FILE")
if [[ "$dupes" != "0" ]]; then
  echo "ERROR: duplicate instance id in catalog" >&2
  errors=$((errors + 1))
fi

if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import jsonschema" 2>/dev/null; then
    python3 <<PY || errors=$((errors + 1))
import json
import sys
from pathlib import Path
try:
    import jsonschema
except ImportError:
    sys.exit(0)

root = Path("$ROOT")
index = json.loads(Path("$FILE").read_text())
record_schema = json.loads((root / "schema/instance-record.v0.json").read_text())
for i, inst in enumerate(index.get("instances", [])):
    jsonschema.validate(inst, record_schema)
print("jsonschema: each instance row OK")
PY
  fi
fi

if [[ "$errors" -gt 0 ]]; then
  echo "validate-index: FAILED ($errors issues)" >&2
  exit 1
fi

echo "validate-index: OK — $FILE"
jq -r '"\(.instances | length) instance(s), updated_at=\(.updated_at)"' "$FILE"
