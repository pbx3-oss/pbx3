#!/usr/bin/env bash
# Run TLS implementation step tests (0–4). Non-zero exit if any step exits non-zero.
if [ -z "${BASH_VERSION:-}" ]; then
	echo "This script requires bash, not sh/dash. Use: bash \"$0\"" >&2
	exit 1
fi
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED=0
for s in step0.sh step1.sh step2.sh step3.sh step4.sh; do
	echo ""
	echo "######## $s ########"
	if ! bash "$SCRIPT_DIR/$s"; then
		FAILED=1
	fi
done
echo ""
if [[ "$FAILED" -ne 0 ]]; then
	echo "[SUMMARY] One or more steps reported FAIL (exit 1)."
	exit 1
fi
echo "[SUMMARY] All step scripts exited 0 (PASS and/or SKIP only)."
exit 0
