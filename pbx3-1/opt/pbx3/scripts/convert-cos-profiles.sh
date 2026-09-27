#!/bin/sh
# Idempotent convert: ipphonecos* junction matrices → cos_profile + ipphone.cos_profile.
# Requires schema from apply-sqlite-add-cos-profiles.sh first.
# GenAst still uses junctions until Slice B — this only populates profile rows.
# Usage: convert-cos-profiles.sh [/path/to/sqlite.db]
#
# Accept: same open/closed deny membership after convert (junctions left intact).
# Fingerprint = (sorted open cos_pkeys, sorted closed cos_pkeys); oride* not in fingerprint.
set -eu

DB="${1:-/opt/pbx3/db/sqlite.db}"
IDPWGEN="${IDPWGEN:-/opt/pbx3/golang/idpwgen}"
SHORTUID_CHARSET='0123456789bcdfghjkmnpqrstvwxyz'

if [ ! -f "$DB" ]; then
	echo "convert-cos-profiles: no DB at $DB" >&2
	exit 1
fi
command -v sqlite3 >/dev/null 2>&1 || {
	echo "convert-cos-profiles: sqlite3 not found" >&2
	exit 1
}

has_col() {
	table="$1"
	col="$2"
	sqlite3 "$DB" "PRAGMA table_info($table);" | awk -F'|' '{print $2}' | grep -qx "$col"
}

has_table() {
	sqlite3 "$DB" "SELECT 1 FROM sqlite_master WHERE type='table' AND name='$1';" | grep -q 1
}

_COS_SUID_SEQ=0
gen_shortuid() {
	tries=0
	while [ "$tries" -lt 64 ]; do
		if [ -x "$IDPWGEN" ]; then
			suid=$("$IDPWGEN" -length 6 -charset "$SHORTUID_CHARSET" 2>/dev/null | tr 'A-Z' 'a-z' | tr -d '[:space:]')
			if [ -z "$suid" ]; then
				suid=$("$IDPWGEN" 6 "$SHORTUID_CHARSET" 2>/dev/null | tr 'A-Z' 'a-z' | tr -d '[:space:]')
			fi
		elif command -v php >/dev/null 2>&1; then
			_COS_SUID_SEQ=$((_COS_SUID_SEQ + 1))
			suid=$(php -r '$c=$argv[1]; $o=""; for($i=0;$i<6;$i++) $o.=$c[random_int(0,strlen($c)-1)]; echo $o;' "$SHORTUID_CHARSET")
		else
			_COS_SUID_SEQ=$((_COS_SUID_SEQ + 1))
			seed=$(($(date +%s 2>/dev/null || echo 0) + $$ + _COS_SUID_SEQ * 1000003 + tries))
			suid=$(awk -v charset="$SHORTUID_CHARSET" -v seed="$seed" 'BEGIN {
				srand(seed);
				n = length(charset);
				out = "";
				for (i = 0; i < 6; i++) out = out substr(charset, int(rand() * n) + 1, 1);
				print out;
			}')
		fi
		tries=$((tries + 1))
		[ -z "$suid" ] && continue
		case "$suid" in
			*[!0-9]*) printf '%s\n' "$suid"; return 0 ;;
		esac
	done
	echo "convert-cos-profiles: could not allocate shortuid with a letter" >&2
	return 1
}

unique_shortuid() {
	tries=0
	while [ "$tries" -lt 32 ]; do
		suid=$(gen_shortuid) || return 1
		exists=$(sqlite3 "$DB" "SELECT 1 FROM cos_profile WHERE shortuid = '$suid' LIMIT 1;")
		if [ -z "$exists" ]; then
			printf '%s\n' "$suid"
			return 0
		fi
		tries=$((tries + 1))
	done
	echo "convert-cos-profiles: could not allocate unique shortuid" >&2
	return 1
}

sql_escape() {
	printf "%s" "$1" | sed "s/'/''/g"
}

# Sorted comma-joined cos_pkeys for a profile side (empty string if none).
# Subquery ORDER BY — works on SQLite < 3.44 (no group_concat ORDER BY).
profile_side_fp() {
	cluster_esc="$1"
	pkey_esc="$2"
	side="$3"
	table="cos_profile_open"
	[ "$side" = "closed" ] && table="cos_profile_closed"
	sqlite3 "$DB" "SELECT ifnull(group_concat(cos_pkey, ','), '') FROM (SELECT cos_pkey FROM $table WHERE cluster = '$cluster_esc' AND profile_pkey = '$pkey_esc' ORDER BY cos_pkey);"
}

find_profile_for_fp() {
	cluster_esc="$1"
	open_fp="$2"
	closed_fp="$3"
	# Avoid pipe-subshell so return works; pkeys are Asterisk-safe (no spaces).
	# shellcheck disable=SC2044
	for pk in $(sqlite3 "$DB" "SELECT pkey FROM cos_profile WHERE cluster = '$cluster_esc';"); do
		[ -z "$pk" ] && continue
		pk_esc=$(sql_escape "$pk")
		ofp=$(profile_side_fp "$cluster_esc" "$pk_esc" open)
		cfp=$(profile_side_fp "$cluster_esc" "$pk_esc" closed)
		if [ "$ofp" = "$open_fp" ] && [ "$cfp" = "$closed_fp" ]; then
			printf '%s\n' "$pk"
			return 0
		fi
	done
	return 0
}

create_profile() {
	cluster_esc="$1"
	open_fp="$2"
	closed_fp="$3"
	nphones="$4"
	cname="$5"
	desc="$6"

	suid=$(unique_shortuid) || exit 1
	[ -n "$suid" ] || exit 1
	suid_esc=$(sql_escape "$suid")
	id_esc=$(sql_escape "cp$(printf '%s' "$suid" | sed 's/[^0-9a-z]//g')$(awk 'BEGIN{srand(); printf "%08d", int(rand()*1e8)}')")
	cname_esc=$(sql_escape "$cname")
	desc_esc=$(sql_escape "$desc")

	sqlite3 "$DB" <<SQL
INSERT OR IGNORE INTO cos_profile (id, shortuid, pkey, active, cluster, cname, description, is_default, z_updater)
VALUES (
  '$id_esc',
  '$suid_esc',
  '$suid_esc',
  'YES',
  '$cluster_esc',
  '$cname_esc',
  '$desc_esc',
  'NO',
  'convert-cos-profiles'
);
SQL

	# Attach open rules
	if [ -n "$open_fp" ]; then
		old_ifs=$IFS
		IFS=,
		# shellcheck disable=SC2086
		set -- $open_fp
		IFS=$old_ifs
		for cos_pkey in "$@"; do
			[ -z "$cos_pkey" ] && continue
			cos_esc=$(sql_escape "$cos_pkey")
			jid=$(sql_escape "${suid}_o_${cos_pkey}")
			sqlite3 "$DB" <<SQL
INSERT OR IGNORE INTO cos_profile_open (id, cluster, active, profile_pkey, cos_pkey, z_updater)
VALUES ('$jid', '$cluster_esc', 'YES', '$suid_esc', '$cos_esc', 'convert-cos-profiles');
SQL
		done
	fi

	# Attach closed rules
	if [ -n "$closed_fp" ]; then
		old_ifs=$IFS
		IFS=,
		# shellcheck disable=SC2086
		set -- $closed_fp
		IFS=$old_ifs
		for cos_pkey in "$@"; do
			[ -z "$cos_pkey" ] && continue
			cos_esc=$(sql_escape "$cos_pkey")
			jid=$(sql_escape "${suid}_c_${cos_pkey}")
			sqlite3 "$DB" <<SQL
INSERT OR IGNORE INTO cos_profile_closed (id, cluster, active, profile_pkey, cos_pkey, z_updater)
VALUES ('$jid', '$cluster_esc', 'YES', '$suid_esc', '$cos_esc', 'convert-cos-profiles');
SQL
		done
	fi

	printf '%s\n' "$suid"
}

ensure_profile() {
	cluster_esc="$1"
	open_fp="$2"
	closed_fp="$3"
	nphones="$4"

	existing=$(find_profile_for_fp "$cluster_esc" "$open_fp" "$closed_fp" || true)
	if [ -n "${existing:-}" ]; then
		printf '%s\n' "$existing"
		return 0
	fi

	if [ -z "$open_fp" ] && [ -z "$closed_fp" ]; then
		cname="Unrestricted"
		desc="empty open/closed junction fingerprint"
	else
		cname="Migrated ($nphones phones)"
		desc="auto from junction fingerprint"
	fi
	create_profile "$cluster_esc" "$open_fp" "$closed_fp" "$nphones" "$cname" "$desc"
}

if ! has_col ipphone cos_profile || ! has_table cos_profile; then
	echo "convert-cos-profiles: run apply-sqlite-add-cos-profiles.sh first" >&2
	exit 1
fi

# Temp lists so set -e aborts on convert failure (pipe while = subshell).
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
CLUSTERS="$WORKDIR/clusters.txt"
FPS="$WORKDIR/fps.txt"

sqlite3 "$DB" "SELECT DISTINCT trim(coalesce(cluster, 'default')) FROM ipphone;" >"$CLUSTERS"

# Per-tenant: build profiles for phones lacking cos_profile, then ensure a default.
while IFS= read -r cluster || [ -n "${cluster:-}" ]; do
	[ -z "${cluster:-}" ] && continue
	cluster_esc=$(sql_escape "$cluster")

	sqlite3 -separator '|' "$DB" <<SQL >"$FPS"
SELECT
  'fp',
  ifnull((
    SELECT group_concat(cos_pkey, ',')
    FROM (
      SELECT o.cos_pkey FROM ipphonecosopen o
      WHERE o.cluster = i.cluster AND o.ipphone_pkey = i.pkey
      ORDER BY o.cos_pkey
    )
  ), ''),
  ifnull((
    SELECT group_concat(cos_pkey, ',')
    FROM (
      SELECT c.cos_pkey FROM ipphonecosclosed c
      WHERE c.cluster = i.cluster AND c.ipphone_pkey = i.pkey
      ORDER BY c.cos_pkey
    )
  ), ''),
  count(*)
FROM ipphone i
WHERE trim(coalesce(i.cluster, 'default')) = '$cluster_esc'
  AND (i.cos_profile IS NULL OR trim(i.cos_profile) = '')
GROUP BY 2, 3;
SQL

	# Marker column avoids IFS stripping leading empty fields (tab/pipe).
	while IFS='|' read -r _marker open_fp closed_fp nphones || [ -n "${nphones:-}" ]; do
		[ "${_marker:-}" = "fp" ] || continue
		[ -z "${nphones:-}" ] && continue

		pk=$(ensure_profile "$cluster_esc" "${open_fp:-}" "${closed_fp:-}" "$nphones")
		pk_esc=$(sql_escape "$pk")
		open_esc=$(sql_escape "${open_fp:-}")
		closed_esc=$(sql_escape "${closed_fp:-}")

		sqlite3 "$DB" <<SQL
UPDATE ipphone
SET cos_profile = '$pk_esc'
WHERE trim(coalesce(cluster, 'default')) = '$cluster_esc'
  AND (cos_profile IS NULL OR trim(cos_profile) = '')
  AND ifnull((
    SELECT group_concat(cos_pkey, ',')
    FROM (
      SELECT o.cos_pkey FROM ipphonecosopen o
      WHERE o.cluster = ipphone.cluster AND o.ipphone_pkey = ipphone.pkey
      ORDER BY o.cos_pkey
    )
  ), '') = '$open_esc'
  AND ifnull((
    SELECT group_concat(cos_pkey, ',')
    FROM (
      SELECT c.cos_pkey FROM ipphonecosclosed c
      WHERE c.cluster = ipphone.cluster AND c.ipphone_pkey = ipphone.pkey
      ORDER BY c.cos_pkey
    )
  ), '') = '$closed_esc';
SQL
	done <"$FPS"

	# Ensure default profile for tenant (idempotent: leave existing default).
	have_default=$(sqlite3 "$DB" "SELECT 1 FROM cos_profile WHERE cluster = '$cluster_esc' AND upper(trim(is_default)) = 'YES' LIMIT 1;")
	if [ -n "$have_default" ]; then
		continue
	fi

	# Prefer fingerprint of defaultopen/defaultclosed rules only when at least one default* flag is set.
	n_def=$(sqlite3 "$DB" "SELECT count(*) FROM cos WHERE trim(coalesce(cluster, 'default')) = '$cluster_esc' AND (upper(trim(defaultopen)) = 'YES' OR upper(trim(defaultclosed)) = 'YES');")
	def_pk=
	if [ "${n_def:-0}" -gt 0 ]; then
		def_open=$(sqlite3 "$DB" "SELECT ifnull(group_concat(pkey, ','), '') FROM (SELECT pkey FROM cos WHERE trim(coalesce(cluster, 'default')) = '$cluster_esc' AND upper(trim(defaultopen)) = 'YES' ORDER BY pkey);")
		def_closed=$(sqlite3 "$DB" "SELECT ifnull(group_concat(pkey, ','), '') FROM (SELECT pkey FROM cos WHERE trim(coalesce(cluster, 'default')) = '$cluster_esc' AND upper(trim(defaultclosed)) = 'YES' ORDER BY pkey);")
		def_pk=$(find_profile_for_fp "$cluster_esc" "$def_open" "$def_closed" || true)
	fi

	if [ -z "${def_pk:-}" ]; then
		def_pk=$(sqlite3 "$DB" <<SQL
SELECT cos_profile
FROM ipphone
WHERE trim(coalesce(cluster, 'default')) = '$cluster_esc'
  AND cos_profile IS NOT NULL AND trim(cos_profile) != ''
GROUP BY cos_profile
ORDER BY count(*) DESC, cos_profile ASC
LIMIT 1;
SQL
)
	fi

	if [ -z "${def_pk:-}" ]; then
		def_pk=$(ensure_profile "$cluster_esc" "" "" 0)
	fi

	def_esc=$(sql_escape "$def_pk")
	sqlite3 "$DB" <<SQL
UPDATE cos_profile SET is_default = 'NO' WHERE cluster = '$cluster_esc';
UPDATE cos_profile SET is_default = 'YES', z_updater = 'convert-cos-profiles'
WHERE cluster = '$cluster_esc' AND pkey = '$def_esc';
SQL
done <"$CLUSTERS"

profiles=$(sqlite3 "$DB" "SELECT count(*) FROM cos_profile;")
linked=$(sqlite3 "$DB" "SELECT count(*) FROM ipphone WHERE cos_profile IS NOT NULL AND trim(cos_profile) != '';")
phones=$(sqlite3 "$DB" "SELECT count(*) FROM ipphone;")
defaults=$(sqlite3 "$DB" "SELECT count(*) FROM cos_profile WHERE upper(trim(is_default)) = 'YES';")
echo "convert-cos-profiles: profiles=$profiles phones_with_profile=$linked/$phones defaults=$defaults on $DB"
exit 0
