#!/bin/bash

. /opt/pbx3/scripts/bashconfig

# Need to create the work directories in etc/asterisk:-
# callparks, endpoints, iax_trunks, queues, trunks
[ ! -d $SYSPATH/etc/asterisk/callparks ] && mkdir -p $SYSPATH/etc/asterisk/callparks
[ ! -d $SYSPATH/etc/asterisk/endpoints ] && mkdir -p $SYSPATH/etc/asterisk/endpoints
[ ! -d $SYSPATH/etc/asterisk/iax_trunks ] && mkdir -p $SYSPATH/etc/asterisk/iax_trunks
[ ! -d $SYSPATH/etc/asterisk/queues ] && mkdir -p $SYSPATH/etc/asterisk/queues
[ ! -d $SYSPATH/etc/asterisk/trunks ] && mkdir -p $SYSPATH/etc/asterisk/trunks

setvcl() {
# turn on VCL in Globals
    echo "AWS instance detected, setting cloud flags"
    /usr/bin/sqlite3 $SYSDB "UPDATE globals SET vcl=1"
# UFW fleet/solo baseline already allows SSH (:22) and API (:44300). Do not
# permanently open :80/:443 — LE uses le-port80-open/close; API is :44300 only.
    echo "AWS/VCL: UFW baseline keeps 22 + 44300 open; review SG + UFW if needed"
}

# Resolve UFW profile for ufw-apply-baseline.sh (F1 / UFW_SHOREWALL_MIGRATION.md).
# Prefer explicit PBX3_UFW_PROFILE; else fleet when PBX3_FLEET_MODE=true or SBC host set.
pbx3_ufw_profile() {
    if [ -n "${PBX3_UFW_PROFILE:-}" ]; then
        echo "$PBX3_UFW_PROFILE"
        return
    fi
    _env="${PBX3API_ENV:-/opt/pbx3api/.env}"
    if [ -f "$_env" ]; then
        if grep -qE '^[[:space:]]*PBX3_FLEET_MODE=true' "$_env" 2>/dev/null; then
            echo fleet
            return
        fi
        if grep -qE '^[[:space:]]*PBX3_SBC_EGRESS_HOST=' "$_env" 2>/dev/null; then
            echo fleet
            return
        fi
    fi
    echo solo
}


#Copy Asterisk file fragments
[ ! -e /var/spool/asterisk/monstage ] && mkdir -p /var/spool/asterisk/monstage
[ ! -e /var/spool/asterisk/monout ] && mkdir -p /var/spool/asterisk/monout
##[ ! -e /usr/share/asterisk/moh-default ] && mkdir -p /usr/share/asterisk/moh-default
[ ! -e $SYSPATH/bkup ] && mkdir -p $SYSPATH/bkup
[ ! -e $SYSPATH/snap ] && mkdir -p $SYSPATH/snap
#[ ! -e $SYSPATH/www/header.htm ] && /bin/cp -f $SYSPATH/cache/header.htm $SYSPATH/www


usermod -a -G asterisk www-data

# added in 5.0.0-21 for hotdesk 
usermod -a -G www-data asterisk


[ -e /etc/ssmtp/ssmtp.conf ] && chown www-data:www-data /etc/ssmtp/ssmtp.conf && chmod 660 /etc/ssmtp/ssmtp.conf

[ -d $ASTPATH ] && chown -R asterisk:asterisk $ASTPATH
chown -R asterisk:asterisk /var/lib/asterisk
chown -R asterisk:asterisk /usr/share/asterisk/sounds
chown -R asterisk:asterisk /var/log/asterisk
chown -R asterisk:asterisk /var/spool/asterisk

[ -d $ASTPATH ] && chmod -R 664 $ASTPATH
[ -d $ASTPATH ] && find $ASTPATH -type d -exec chmod 755 {} \;   # directories must be 755 to list contents (Asterisk may install with 644)
[ -e $ASTPATH/manager.d ] && chmod +x $ASTPATH/manager.d
chmod 755 -R $SYSPATH/scripts
 
chmod +x $SYSPATH/service/sys-ua-helper/run 
chmod +x $SYSPATH/service/sys-ua-siplog/run


# link the helpers if they don't exist 
[ ! -L /etc/service/sys-ua-helper ] && ln -s $SYSPATH/service/sys-ua-helper /etc/service
[ ! -L /etc/service/sys-ua-siplog ] && ln -s $SYSPATH/service/sys-ua-siplog /etc/service
# Leave sys-ua-siplog down by default (service/…/down). Solo: siplog-set-mode.sh solo
# Fleet onboard also forces fleet mode. See FLEET_LOG_RETENTION_REQUIREMENTS.md R3.
if [ -f "$SYSPATH/service/sys-ua-siplog/down" ]; then
	sv d sys-ua-siplog 2>/dev/null || true
fi

# HTTP server (nginx) and API site are installed by pbx3api; see pbx3api docs.
# Ensure Asterisk (and later www-data for pbx3api) can read TLS certs (e.g. Let's Encrypt).
chmod 751 /etc/ssl/private 2>/dev/null || true
usermod -a -G ssl-cert asterisk 2>/dev/null || true
usermod -a -G ssl-cert www-data 2>/dev/null || true

# Certificates panel: dirs for LE identity and custom (purchased) cert; create nginx snippet (snakeoil until LE/custom).
mkdir -p /opt/pbx3/etc/identity /opt/pbx3/etc/ssl/custom 2>/dev/null || true
mkdir -p /opt/pbx3/var/acme-challenge 2>/dev/null || true
chown www-data:www-data /opt/pbx3/var/acme-challenge 2>/dev/null || true
chmod 755 /opt/pbx3/var/acme-challenge 2>/dev/null || true
[ -x /opt/pbx3/scripts/le-install-nginx-acme.sh ] && /opt/pbx3/scripts/le-install-nginx-acme.sh 2>/dev/null || true
[ -x /opt/pbx3/scripts/apply-active-cert.sh ] && /opt/pbx3/scripts/apply-active-cert.sh 2>/dev/null || true

# Use our versions of asterisk/modules, asterisk/http & asterisk/pjsip

[ ! -e $ASTPATH/modules.conf_installed ] && mv $ASTPATH/modules.conf $ASTPATH/modules.conf_installed
[ ! -L $ASTPATH/modules.conf ] && ln -s $ASTLOCALCONF/modules.conf $ASTPATH/modules.conf
[ ! -e $ASTPATH/http.conf_installed ] && mv $ASTPATH/http.conf $ASTPATH/http.conf_installed
[ ! -L $ASTPATH/http.conf ] && ln -s $ASTLOCALCONF/http.conf $ASTPATH/http.conf
[ ! -e $ASTPATH/pjsip.conf_installed ] && mv $ASTPATH/pjsip.conf $ASTPATH/pjsip.conf_installed
[ ! -L $ASTPATH/pjsip.conf ] && ln -s $ASTLOCALCONF/pjsip.conf $ASTPATH/pjsip.conf

# Asterisk 11+ call parks

[ ! -e $ASTPATH/res_parking.conf_installed ] && mv $ASTPATH/res_parking.conf $ASTPATH/res_parking.conf_installed
[ ! -L $ASTPATH/res_parking.conf ] && ln -s $ASTLOCALCONF/res_parking.conf $ASTPATH/res_parking.conf

#handle multiple NICs
if [ ! -d /etc/network/interfaces.d ]; then
    mkdir -p /etc/network/interfaces.d
fi
# idempotent: add source line only if not already present
grep -q 'source /etc/network/interfaces.d' /etc/network/interfaces 2>/dev/null || echo "source /etc/network/interfaces.d/*" >> /etc/network/interfaces
    
# set correct Asterisk dateformat in logger.conf (idempotent: only when present)
if [ -f $ASTPATH/logger.conf ]; then
    sed -i 's/^;dateformat=%F %T /dateformat=%F %T/' $ASTPATH/logger.conf
    sed -i '/^messages/c \messages => security,notice,warning,error' $ASTPATH/logger.conf
    /usr/sbin/asterisk -rx 'logger reload' 2>/dev/null || true
fi

# Firewall: UFW is the home product path (UFW_SHOREWALL_MIGRATION.md).
# Shorewall templates may still exist in the package tree for archaeology /
# pre-cutover hosts — do not enable or copy them as live config (Phase 2).
# Ensure fqdninspect/sipflood cannot resurrect STRING/limit INLINE under UFW.
if [ -f "$SYSDB" ]; then
    /usr/bin/sqlite3 "$SYSDB" "UPDATE globals SET fqdninspect='NO', sipflood='NO';" 2>/dev/null || true
fi

# Instance identity (applied only on fresh DB rebuild, unless PBX3_APPLY_INSTANCE_IDENTITY=1 — see below).
# FQDN = {shortuid}.{DOMAIN_TLD}; hostname = shortuid (opaque). Friendly Name = sitename (INSTANCE_SITENAME).
# DOMAIN_TLD: env DOMAIN_TLD, else globals.domain from existing DB, else prompt (default pbx3.com), else pbx3.com.
# Subdomain/shortuid: 6-char idpwgen opaque unless recovering existing DB, or INSTANCE_FQDN with opaque label.
# Vanity INSTANCE_FQDN (e.g. kildare.pbx3.com) is rejected unless PBX3_ALLOW_VANITY_FQDN=1 (lab debt only).
# Site name (friendly Name): env INSTANCE_SITENAME, else prompt on first provision → globals.sitename
#   (Home / Network; not hostname). Empty allowed → SPA falls back to shortuid.

normalize_fqdn() {
    echo "$1" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]'
}
valid_fqdn() {
    [ -n "$1" ] && case "$1" in *.*) true ;; *) false ;; esac
}
# Opaque shortuid / FQDN first label: 6 chars, idpwgen charset (no vowels / ambiguous).
opaque_shortuid() {
    echo "$1" | grep -Eq '^[0-9bcdfghjkmnpqrstvwxyz]{6}$' && echo "$1" | grep -Eq '[bcdfghjkmnpqrstvwxyz]'
}
# Friendly site name: trim ends only; keep case and internal spaces.
normalize_sitename() {
    # shellcheck disable=SC2001
    echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Build idpwgen on *this* host only. Do not copy /opt/pbx3/golang/idpwgen from another OS or arch
# (e.g. macOS arm64 and Linux arm64 are not interchangeable — "cannot execute binary file: Exec format error").
if [ -f $SYSPATH/golang/idpwgen.go ] && command -v go >/dev/null 2>&1; then
    rm -f "$SYSPATH/golang/idpwgen"
    if (cd "$SYSPATH/golang" && go build -o idpwgen idpwgen.go); then
        chmod 755 "$SYSPATH/golang/idpwgen" 2>/dev/null || true
    else
        echo "Warning: idpwgen build failed; run: cd $SYSPATH/golang && go build -o idpwgen idpwgen.go" >&2
    fi
fi

# Snapshot env before we clear shell variables (legacy INSTANCE_FQDN and DOMAIN_TLD are both optional).
_ENV_TLD=$(normalize_fqdn "${DOMAIN_TLD}")
_LEGACY_FQDN=$(normalize_fqdn "${INSTANCE_FQDN}")
_ENV_SITENAME=$(normalize_sitename "${INSTANCE_SITENAME}")
INSTANCE_SUBDOMAIN=""
DOMAIN_TLD=""
INSTANCE_FQDN=""
INSTANCE_SITENAME=""
if [ -n "$_ENV_SITENAME" ]; then
    INSTANCE_SITENAME="$_ENV_SITENAME"
fi

if valid_fqdn "$_LEGACY_FQDN"; then
    INSTANCE_SUBDOMAIN=$(echo "$_LEGACY_FQDN" | cut -d. -f1)
    DOMAIN_TLD=$(echo "$_LEGACY_FQDN" | cut -d. -f2-)
    if opaque_shortuid "$INSTANCE_SUBDOMAIN"; then
        INSTANCE_FQDN="$_LEGACY_FQDN"
    elif [ "${PBX3_ALLOW_VANITY_FQDN:-}" = "1" ]; then
        echo "WARNING: PBX3_ALLOW_VANITY_FQDN=1 — accepting vanity INSTANCE_FQDN=$_LEGACY_FQDN (lab debt; prefer opaque shortuid + INSTANCE_SITENAME)." >&2
        INSTANCE_FQDN="$_LEGACY_FQDN"
    else
        echo "ERROR: INSTANCE_FQDN first label must be opaque 6-char shortuid (idpwgen), not a vanity name like 'kildare'." >&2
        echo "  Use: DOMAIN_TLD=pbx3.com INSTANCE_SITENAME='Kildare'  (FQDN becomes {idpwgen}.pbx3.com)" >&2
        echo "  Or lab override: PBX3_ALLOW_VANITY_FQDN=1 INSTANCE_FQDN=..." >&2
        echo "  See pbx3/workingdocs/FLEET_NAMING_LOCK.md" >&2
        exit 1
    fi
fi

if [ -z "$DOMAIN_TLD" ] && valid_fqdn "$_ENV_TLD"; then
    DOMAIN_TLD="$_ENV_TLD"
fi
if [ -z "$DOMAIN_TLD" ] && [ -e "$SYSDB" ]; then
    DOMAIN_TLD=$(normalize_fqdn "$(sqlite3 "$SYSDB" "SELECT domain FROM globals WHERE domain IS NOT NULL AND domain != '' LIMIT 1" 2>/dev/null)")
fi
if [ -z "$DOMAIN_TLD" ] && [ -t 0 ]; then
    printf "Domain apex — press Enter for pbx3.com: " >&2
    read -r _tld_in
    _tld_in=$(normalize_fqdn "$_tld_in")
    if [ -z "$_tld_in" ]; then
        DOMAIN_TLD="pbx3.com"
    else
        DOMAIN_TLD="$_tld_in"
    fi
fi
if [ -z "$DOMAIN_TLD" ]; then
    DOMAIN_TLD="pbx3.com"
fi
if ! valid_fqdn "$DOMAIN_TLD"; then
    echo "Invalid DOMAIN_TLD (need at least one dot, e.g. pbx3.com): $DOMAIN_TLD" >&2
    DOMAIN_TLD="pbx3.com"
fi

if [ -z "$INSTANCE_SUBDOMAIN" ] && [ -e "$SYSDB" ]; then
    _fq=$(normalize_fqdn "$(sqlite3 "$SYSDB" "SELECT fqdn FROM globals WHERE fqdn IS NOT NULL AND fqdn != '' LIMIT 1" 2>/dev/null)")
    _dm=$(normalize_fqdn "$(sqlite3 "$SYSDB" "SELECT domain FROM globals WHERE domain IS NOT NULL AND domain != '' LIMIT 1" 2>/dev/null)")
    if [ -z "$_dm" ]; then
        _dm="$DOMAIN_TLD"
    fi
    if [ -n "$_fq" ] && valid_fqdn "$_dm" ]; then
        _suf=".${_dm}"
        case "$_fq" in
            *"${_suf}")
                INSTANCE_SUBDOMAIN=${_fq%"${_suf}"}
                ;;
        esac
    fi
fi

if [ -z "$INSTANCE_SUBDOMAIN" ]; then
    if [ -x "$SYSPATH/golang/idpwgen" ]; then
        INSTANCE_SUBDOMAIN=$("$SYSPATH/golang/idpwgen" | tr -d '[:space:]')
    else
        echo "ERROR: $SYSPATH/golang/idpwgen not found or not executable (install golang-go and re-run, or set INSTANCE_FQDN=sub.example.com)." >&2
    fi
fi

# DNS labels are case-insensitive; keep the subdomain canonical lowercase (human + URL consistency).
if [ -n "$INSTANCE_SUBDOMAIN" ]; then
    INSTANCE_SUBDOMAIN=$(normalize_fqdn "$INSTANCE_SUBDOMAIN")
fi

if [ -n "$INSTANCE_SUBDOMAIN" ] && [ -n "$DOMAIN_TLD" ]; then
    INSTANCE_FQDN="${INSTANCE_SUBDOMAIN}.${DOMAIN_TLD}"
fi

# Regenerate bashconfig from config.php when PHP is available (package ships bashconfig so install works without PHP)
if command -v php >/dev/null 2>&1; then
    php $SYSPATH/php/utilities/genbashconfig.php 2>/dev/null || true
fi

_DB_ALREADY=0
[ -f "$SYSDB" ] && _DB_ALREADY=1

# Create skeleton DB only when none exists (fresh install); do not recreate if already present.
[ "$_DB_ALREADY" -eq 0 ] && /bin/sh $SCRIPTS/create.initial.db

_APPLY_IDENT=0
if [ "$_DB_ALREADY" -eq 0 ]; then
    echo "No existing $SYSDB: building database via reloader.sh (first provision only)."
    /bin/sh $SCRIPTS/reloader.sh
    chmod 775 $DBPATH
    chmod 664 $SYSDB
    _APPLY_IDENT=1
else
    echo "Existing $SYSDB: skipping reloader.sh (tenant data and instance FQDN are preserved)."
    chmod 775 $DBPATH 2>/dev/null || true
    chmod 664 $SYSDB 2>/dev/null || true
    if [ -x "$SCRIPTS/normalize-globals-identity.sh" ]; then
        /bin/sh "$SCRIPTS/normalize-globals-identity.sh" || true
    fi
    # Explicit host migration only: INSTANCE_FQDN=opaque.example.com PBX3_APPLY_INSTANCE_IDENTITY=1 installer.sh
    if [ "${PBX3_APPLY_INSTANCE_IDENTITY:-}" = "1" ] && valid_fqdn "$_LEGACY_FQDN"; then
        INSTANCE_SUBDOMAIN=$(echo "$_LEGACY_FQDN" | cut -d. -f1)
        DOMAIN_TLD=$(echo "$_LEGACY_FQDN" | cut -d. -f2-)
        if opaque_shortuid "$INSTANCE_SUBDOMAIN" || [ "${PBX3_ALLOW_VANITY_FQDN:-}" = "1" ]; then
            INSTANCE_FQDN="$_LEGACY_FQDN"
            echo "PBX3_APPLY_INSTANCE_IDENTITY=1: applying INSTANCE_FQDN=$INSTANCE_FQDN"
            _APPLY_IDENT=1
        else
            echo "ERROR: PBX3_APPLY_INSTANCE_IDENTITY with vanity INSTANCE_FQDN rejected (set PBX3_ALLOW_VANITY_FQDN=1 for lab debt)." >&2
            exit 1
        fi
    fi
fi

# Site name (friendly Name → globals.sitename). Prompt on first provision / identity apply when unset.
if [ "$_APPLY_IDENT" -eq 1 ] && [ -z "$INSTANCE_SITENAME" ] && [ -t 0 ]; then
    printf "Site name (friendly Name for Home / Network, e.g. Kildare) []: " >&2
    read -r _site_in
    INSTANCE_SITENAME=$(normalize_sitename "$_site_in")
fi

# Store instance domain + FQDN in globals; hostname = subdomain (fresh build or explicit migrate)
if [ "$_APPLY_IDENT" -eq 1 ] && [ -n "$INSTANCE_FQDN" ] && [ -n "$DOMAIN_TLD" ] && [ -n "$INSTANCE_SUBDOMAIN" ]; then
    _sql_dom=$(echo "$DOMAIN_TLD" | sed "s/'/''/g")
    _sql_fq=$(echo "$INSTANCE_FQDN" | sed "s/'/''/g")
    sqlite3 $SYSDB "UPDATE globals SET domain='$_sql_dom', fqdn='$_sql_fq', shortuid='$(echo "$INSTANCE_SUBDOMAIN" | sed "s/'/''/g")' WHERE rowid=(SELECT rowid FROM globals LIMIT 1);"
    if [ -n "$INSTANCE_SITENAME" ]; then
        _sql_site=$(echo "$INSTANCE_SITENAME" | sed "s/'/''/g")
        sqlite3 $SYSDB "UPDATE globals SET sitename='$_sql_site' WHERE rowid=(SELECT rowid FROM globals LIMIT 1);"
        echo "Set globals.sitename to $INSTANCE_SITENAME"
    fi
    # Option A / Step 0.2: default tenant row holds node FQDN for cert + firewall domain lists (GET tenants).
    _defcnt=$(sqlite3 "$SYSDB" "SELECT COUNT(*) FROM cluster WHERE pkey='default';" 2>/dev/null || echo 0)
    if [ "${_defcnt:-0}" -ge 1 ]; then
        sqlite3 "$SYSDB" "UPDATE cluster SET fqdn='$_sql_fq', domain='$_sql_fq' WHERE pkey='default';"
        echo "Set default tenant fqdn/domain to $INSTANCE_FQDN"
    else
        echo "Note: no cluster row pkey=default; skip default tenant fqdn (unexpected empty DB)" >&2
    fi
    if /usr/bin/hostnamectl set-hostname "$INSTANCE_SUBDOMAIN" 2>/dev/null; then
        :
    else
        echo "$INSTANCE_SUBDOMAIN" > /etc/hostname
        hostname "$INSTANCE_SUBDOMAIN" 2>/dev/null || true
    fi
    # Update /etc/hosts so 127.0.1.1 points to the new hostname (replace existing or add)
    if [ -f /etc/hosts ]; then
        sed -i 's/^127\.0\.1\.1[[:space:]].*/127.0.1.1\t'"$INSTANCE_SUBDOMAIN"'/' /etc/hosts
        grep -q '^127\.0\.1\.1[[:space:]]' /etc/hosts || sed -i '2i 127.0.1.1\t'"$INSTANCE_SUBDOMAIN" /etc/hosts
    fi
    echo "Set globals.domain to $DOMAIN_TLD, globals.fqdn to $INSTANCE_FQDN, globals.shortuid to $INSTANCE_SUBDOMAIN, hostname to $INSTANCE_SUBDOMAIN"
fi

if [ -x "$SCRIPTS/normalize-globals-identity.sh" ]; then
    /bin/sh "$SCRIPTS/normalize-globals-identity.sh" || true
fi

# First SPA admin (no seeded password). Skip if users already exist.
# Interactive prompts on TTY; non-interactive: PBX3_ADMIN_EMAIL + PBX3_ADMIN_PASSWORD.
# Existing nodes with unknown seeded admin@pbx3.com: bootstrap-admin-user.sh --reset
# Must use bash (script uses [[ ]] / pipefail). /bin/sh (dash) fails before any prompt.
if [ -f "$SYSDB" ] && [ -x "$SCRIPTS/bootstrap-admin-user.sh" ]; then
    /bin/bash "$SCRIPTS/bootstrap-admin-user.sh" "$SYSDB" || {
        echo "WARNING: Admin SPA user bootstrap failed or skipped. On TTY re-run:" >&2
        echo "  sudo $SCRIPTS/bootstrap-admin-user.sh" >&2
        echo "  or: sudo PBX3_ADMIN_EMAIL=… PBX3_ADMIN_PASSWORD=… $SCRIPTS/bootstrap-admin-user.sh" >&2
    }
    _boot_uc=$(sqlite3 "$SYSDB" "SELECT COUNT(*) FROM users;" 2>/dev/null || echo 0)
    if [ "${_boot_uc:-0}" -lt 1 ]; then
        echo "WARNING: No SPA admin in users table after bootstrap." >&2
        echo "  Installer continues, but login will fail until you create one." >&2
    fi
fi

# Run setip once (network detection, /etc/pbx3/lan.cidr, fail2ban ignoreip, Asterisk localnet, /etc/issue)
# Previously a systemd oneshot at boot; we run it here so the installer does not depend on it.
echo running setip to resolve IP addresses
/usr/bin/php $SYSPATH/php/utilities/setip.php
# Remove the systemd unit so it is not loaded at boot (setip is run once by the installer only)
systemctl disable debsetlan.service 2>/dev/null || true
rm -f /etc/systemd/system/debsetlan.service
systemctl daemon-reload 2>/dev/null || true

# F2b setup — Ubuntu 24.04 LTS (jail.d fragments; banaction=ufw; do not symlink jail.local)
mkdir -p /etc/fail2ban/jail.d
if [ -L /etc/fail2ban/jail.local ] && [ "$(readlink /etc/fail2ban/jail.local 2>/dev/null)" = "$SYSPATH/etc/fail2ban/jail.local" ]; then
	rm -f /etc/fail2ban/jail.local
fi
# Drop legacy Shorewall banaction symlink if present (Phase 2 → ufw).
[ -L /etc/fail2ban/action.d/shorewall.local ] && rm -f /etc/fail2ban/action.d/shorewall.local
if [ -f "$SYSPATH/etc/fail2ban/jail.d/pbx3-jails.conf" ]; then
	ln -sf "$SYSPATH/etc/fail2ban/jail.d/pbx3-jails.conf" /etc/fail2ban/jail.d/pbx3-jails.conf
fi
if [ -f "$SYSPATH/etc/fail2ban/jail.d/pbx3-api.conf" ]; then
	ln -sf "$SYSPATH/etc/fail2ban/jail.d/pbx3-api.conf" /etc/fail2ban/jail.d/pbx3-api.conf
fi
if command -v fail2ban-client >/dev/null 2>&1; then
	if fail2ban-client -t >/dev/null 2>&1; then
		fail2ban-client reload >/dev/null 2>&1 || systemctl reload fail2ban >/dev/null 2>&1 || true
	else
		echo "Warning: fail2ban config test failed; run: sudo fail2ban-client -t" >&2
	fi
fi





#Check if I am an AWS instance and set defaults accordingly

dmidecode -s bios-version | grep -i amazon
if [ "$?" -eq "0" ] ; then
    setvcl
else
    dmidecode -s bios-vendor | grep -i amazon
    if [ "$?" -eq "0" ] ; then
        setvcl
    fi
fi

# Enable UFW baseline (stops/disables Shorewall if present — F7).
# Allow rules before default deny are handled inside ufw-apply-baseline.sh.
_ufw_profile=$(pbx3_ufw_profile)
echo "Applying UFW baseline (profile=${_ufw_profile})"
if [ -x "$SCRIPTS/ufw-apply-baseline.sh" ]; then
    if ! "$SCRIPTS/ufw-apply-baseline.sh" "$_ufw_profile"; then
        echo "ERROR: ufw-apply-baseline.sh failed (profile=${_ufw_profile}). SSH may be open until fixed." >&2
        exit 1
    fi
else
    echo "ERROR: missing $SCRIPTS/ufw-apply-baseline.sh" >&2
    exit 1
fi


# call recording 
[ ! -d $SYSPATH/media/recordings/default ] && mkdir -p $SYSPATH/media/recordings/default


#stop and restart the helper to reset the socket
sv d sys-ua-helper
sleep 1
sv u sys-ua-helper

# CDR MySQL: create asterisk DB and cdr table for Asterisk CDR records (run when MySQL/MariaDB is present)
# cdr-mysql-setup.sql is idempotent; safe to run on every install.
# Use Unix socket so root connects with socket auth (same as interactive "sudo mysql -u root")
if command -v mysql >/dev/null 2>&1; then
    echo "Setting up MySQL database for Asterisk CDR..."
    MYSQL_SOCK="${MYSQL_SOCK:-/var/run/mysqld/mysqld.sock}"
    if [ -S "$MYSQL_SOCK" ] && mysql -u root --socket="$MYSQL_SOCK" < "$SYSPATH/cache/cdr-mysql-setup.sql" 2>/dev/null; then
        echo "CDR MySQL setup done (database asterisk, user asterisk)."
    elif mysql -u root < "$SYSPATH/cache/cdr-mysql-setup.sql" 2>/dev/null; then
        echo "CDR MySQL setup done (database asterisk, user asterisk)."
    else
        echo "CDR MySQL setup skipped or failed (e.g. root password required). Run manually: mysql -u root -p < $SYSPATH/cache/cdr-mysql-setup.sql" >&2
    fi
else
    echo "MySQL/MariaDB not found; CDR-to-MySQL skipped. Install mysql-server or mariadb-server and run: mysql -u root -p < $SYSPATH/cache/cdr-mysql-setup.sql"
fi

#stop systemd.resolved - it interferes with dnsmasq
systemctl stop systemd-resolved
systemctl disable systemd-resolved
#restart dnsmasq
systemctl enable dnsmasq
systemctl restart dnsmasq

if [ ! -d $SYSPATH/recmnt ]; then 
    mkdir $SYSPATH/recmnt
    chown www-data:www-data $SYSPATH/recmnt
    chmod 755 $SYSPATH/recmnt
fi

# Always print identity at the end — operators need these for DNS / LE / fleet worksheet.
# Mid-script "Set globals…" is easy to miss; KSUID was never shown before.
if [ -f "$SYSDB" ] && command -v sqlite3 >/dev/null 2>&1; then
    _sum_id=$(sqlite3 "$SYSDB" "SELECT id FROM globals WHERE pkey='global' LIMIT 1;" 2>/dev/null)
    _sum_su=$(sqlite3 "$SYSDB" "SELECT shortuid FROM globals WHERE pkey='global' LIMIT 1;" 2>/dev/null)
    _sum_fq=$(sqlite3 "$SYSDB" "SELECT fqdn FROM globals WHERE pkey='global' LIMIT 1;" 2>/dev/null)
    _sum_sn=$(sqlite3 "$SYSDB" "SELECT sitename FROM globals WHERE pkey='global' LIMIT 1;" 2>/dev/null)
    if [ -z "$_sum_id" ]; then
        _sum_id=$(sqlite3 "$SYSDB" "SELECT id FROM globals LIMIT 1;" 2>/dev/null)
        _sum_su=$(sqlite3 "$SYSDB" "SELECT shortuid FROM globals LIMIT 1;" 2>/dev/null)
        _sum_fq=$(sqlite3 "$SYSDB" "SELECT fqdn FROM globals LIMIT 1;" 2>/dev/null)
        _sum_sn=$(sqlite3 "$SYSDB" "SELECT sitename FROM globals LIMIT 1;" 2>/dev/null)
    fi
    _sum_ip=$(curl -4 -sS --connect-timeout 3 https://checkip.amazonaws.com 2>/dev/null | tr -d '[:space:]')
    [ -z "$_sum_ip" ] && _sum_ip=$(curl -4 -sS --connect-timeout 3 https://ifconfig.me 2>/dev/null | tr -d '[:space:]')
    [ -z "$_sum_ip" ] && _sum_ip='(this node public IP / EIP)'

    echo ""
    echo "======== Instance identity (copy to worksheet) ========"
    echo "  KSUID (id)  ${_sum_id}"
    echo "  shortuid    ${_sum_su}"
    echo "  fqdn        ${_sum_fq}"
    echo "  sitename    ${_sum_sn}   (friendly Name only — NOT a DNS name)"
    echo ""
    echo "  Worksheet exports:"
    echo "    export KSUID=${_sum_id}"
    echo "    export SHORTUID=${_sum_su}"
    echo "    export INSTANCE_FQDN=${_sum_fq}"
    echo ""
    echo "-------- DNS (required before Let's Encrypt) --------"
    echo "  Create ONE public A record:"
    echo "    Name:  ${_sum_fq}"
    echo "    Type:  A"
    echo "    Value: ${_sum_ip}"
    echo ""
    echo "  That fqdn is the only instance hostname for TLS and the API."
    echo "  Do NOT point Let's Encrypt at a vanity SSH nickname"
    echo "  (e.g. virginia1.pbx3.com) unless it equals fqdn above."
    echo "  sitename is a label in the Admin UI — it is not DNS."
    echo ""
    echo "  After the A record propagates:"
    echo "    dig +short ${_sum_fq}"
    echo "    # must print: ${_sum_ip}"
    echo "    sudo /opt/pbx3/scripts/le-instance-bootstrap.sh your@email.com"
    _sum_uc=$(sqlite3 "$SYSDB" "SELECT COUNT(*) FROM users;" 2>/dev/null || echo 0)
    echo ""
    if [ "${_sum_uc:-0}" -ge 1 ]; then
        echo "  SPA admin users: ${_sum_uc} (OK)"
    else
        echo "  SPA admin users: 0 — NO LOGIN YET"
        echo "  Create one now (use YOUR real email — not a docs placeholder):"
        echo "    sudo PBX3_ADMIN_EMAIL='you@example.com' PBX3_ADMIN_PASSWORD='…' \\"
        echo "      /opt/pbx3/scripts/bootstrap-admin-user.sh"
        echo "    # replace you@example.com — bootstrap refuses common placeholder addresses"
        echo "    or interactive: sudo /opt/pbx3/scripts/bootstrap-admin-user.sh"
    fi
    echo "======================================================="
fi

# GenAst stubs + /etc/asterisk symlinks (pjsip_ready_*.conf etc.) — once per provision.
if [ -x "$SCRIPTS/link-asterisk-configs.sh" ]; then
    /bin/sh "$SCRIPTS/link-asterisk-configs.sh" 2>/dev/null || true
fi
