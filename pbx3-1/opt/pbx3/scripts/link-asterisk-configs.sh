#!/bin/bash
# Ensure GenAst output files exist under ASTLOCALCONF and symlink /etc/asterisk → configs.
# Install/upgrade only (postinst, installer.sh, install-home-host.sh) — not on every Commit.
#
# GenAst overwrites these files in place; runLinker only needs them to exist once so
# /etc/asterisk/pjsip_ready_*.conf (etc.) symlinks are created at first provision.

set -euo pipefail

SYSPATH="${SYSPATH:-/opt/pbx3}"
CONF="${SYSPATH}/etc/asterisk/configs"

stubs=(
	pjsip_ready_trunks.conf
	pjsip_ready_phones.conf
	pjsip_ready_webrtc.conf
	iax_ready_trunks.conf
	ready_queues.conf
	ready_parks.conf
	extensions.conf
	voicemail.conf
	moh_extra.conf
)

mkdir -p "$CONF"
for f in "${stubs[@]}"; do
	if [[ ! -f "$CONF/$f" ]]; then
		printf ';\n' >"$CONF/$f"
	fi
done

if id asterisk >/dev/null 2>&1; then
	chown asterisk:asterisk "$CONF" 2>/dev/null || true
	chmod 2775 "$CONF" 2>/dev/null || true
	for f in "${stubs[@]}"; do
		if [[ -f "$CONF/$f" ]]; then
			chown asterisk:asterisk "$CONF/$f" 2>/dev/null || true
			chmod 664 "$CONF/$f" 2>/dev/null || true
		fi
	done
fi

if command -v php >/dev/null 2>&1 && [[ -f "$SYSPATH/php/utilities/runLinker.php" ]]; then
	php "$SYSPATH/php/utilities/runLinker.php" >/dev/null 2>&1 || true
fi
