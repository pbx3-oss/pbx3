#!/bin/bash

. /opt/pbx3/scripts/bashconfig
[ ! -e $SYSDB ] && exit 4

# Phone outbound_proxy follows Egress host when env is unset (lab SPA Commit
# does not pass PBX3_SBC_EGRESS_HOST; default sbc.pbx3.com sends calls off-LAN).
if [ -z "${PBX3_SBC_EGRESS_HOST:-}" ] && command -v sqlite3 >/dev/null 2>&1; then
  _h="$(sqlite3 "$SYSDB" "SELECT host FROM trunks WHERE pkey='Egress' AND active='YES' LIMIT 1;" 2>/dev/null || true)"
  if [ -n "$_h" ]; then
    export PBX3_SBC_EGRESS_HOST="$_h"
  fi
fi

/usr/bin/logger Regenerating Asterisk

php $ASTGEN

# GenAst writes under ASTLOCALCONF. Asterisk must read those files via symlink
# from /etc/asterisk (runLinker / link-asterisk-configs.sh at install). If a
# regular file ever replaces the symlink (e.g. `cp` over a link), Commit looks
# like a no-op — live dialplan stays stale. Re-assert links after every gen.
ensure_ast_symlink() {
	local name="$1"
	local ast="${ASTPATH}/${name}"
	local loc="${ASTLOCALCONF}/${name}"
	[ -f "$loc" ] || return 0
	if [ -L "$ast" ]; then
		[ "$(readlink "$ast")" = "$loc" ] && return 0
		/bin/rm -f "$ast"
	elif [ -e "$ast" ]; then
		if [ ! -e "${ast}_installed" ]; then
			/bin/mv "$ast" "${ast}_installed"
		else
			/bin/rm -f "$ast"
		fi
	fi
	/bin/ln -s "$loc" "$ast"
}

ensure_ast_symlink extensions.conf
ensure_ast_symlink voicemail.conf
ensure_ast_symlink features.conf
ensure_ast_symlink moh_extra.conf
ensure_ast_symlink extensions_park_timeout.conf

# copy the DB
/bin/cp $SYSDB $COPY_DB
/bin/mv $COPY_DB $READONLY_DB
#
/usr/bin/logger Regenerating Asterisk Finished
#/usr/bin/sqlite3 $SYSDB "UPDATE globals SET mycommit='NO';"
