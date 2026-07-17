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
# open 80,443 and 22 in the firewall (otherwise we'll be locked out)
    echo "WARNING!!!  Ports 80, 443 and 22 have been opened to prevent AWS lockout - you should review these and set sensible values"
    sed -i 's/ACCEPT net:$LAN $FW tcp 80/ACCEPT net $FW tcp 80/' $FW_RULES
    sed -i 's/ACCEPT net:$LAN $FW tcp 443/ACCEPT net $FW tcp 443/' $FW_RULES
    sed -i 's/ACCEPT net:$LAN $FW tcp 22/ACCEPT net $FW tcp 22/' $FW_RULES 
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

#Shorewall setup
if [ -d $SHOREWALL ]; then
    sed -i 's/startup=0/startup=1/' /etc/default/shorewall
    sed -i "/^SAVE_IPSETS/c\SAVE_IPSETS=Yes" $SHOREWALL/shorewall.conf
    echo 'INCLUDE local.lan' > $SHOREWALL/params
    echo 'INCLUDE local.if1' >> $SHOREWALL/params

    cp -f $SYSPATH/etc/shorewall/rules $SHOREWALL/rules
    cp -f $SYSPATH/etc/shorewall/pbx3_rules $SHOREWALL/pbx3_rules
    #for pre 5.x upgrades check that 443 is open (otherwise they won't be able to login)
    grep  -q "tcp\s*443\s*" $FW_RULES
    if [  "$?" -ne "0" ] ; then
        echo ACCEPT net:\$LAN \$FW tcp 443 - - >> $FW_RULES 
    fi
    cp -f $SYSPATH/etc/shorewall/pbx3_inline_fqdn $SHOREWALL/pbx3_inline_fqdn
    cp -f $SYSPATH/etc/shorewall/pbx3_inline_limit $SHOREWALL/pbx3_inline_limit
    chown www-data:www-data $FW_RULES
    chown www-data:www-data $SHOREWALL/pbx3_inline_fqdn
    chown www-data:www-data $SHOREWALL/pbx3_inline_limit
fi

# Instance identity (applied only on fresh DB rebuild, unless PBX3_APPLY_INSTANCE_IDENTITY=1 — see below).
# FQDN = {subdomain}.{DOMAIN_TLD}; hostname = subdomain (for Let's Encrypt later).
# DOMAIN_TLD: env DOMAIN_TLD, else globals.domain from existing DB, else prompt (default pbx3.com), else pbx3.com.
# Subdomain: 6 chars from idpwgen unless INSTANCE_FQDN legacy env, or existing fqdn+domain in DB match.
# Legacy: INSTANCE_FQDN=node1.pbx3.com -> subdomain=node1, TLD=rest (e.g. pbx3.com).

normalize_fqdn() {
    echo "$1" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]'
}
valid_fqdn() {
    [ -n "$1" ] && case "$1" in *.*) true ;; *) false ;; esac
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
INSTANCE_SUBDOMAIN=""
DOMAIN_TLD=""
INSTANCE_FQDN=""

if valid_fqdn "$_LEGACY_FQDN"; then
    INSTANCE_SUBDOMAIN=$(echo "$_LEGACY_FQDN" | cut -d. -f1)
    DOMAIN_TLD=$(echo "$_LEGACY_FQDN" | cut -d. -f2-)
    INSTANCE_FQDN="$_LEGACY_FQDN"
fi

if [ -z "$DOMAIN_TLD" ] && valid_fqdn "$_ENV_TLD"; then
    DOMAIN_TLD="$_ENV_TLD"
fi
if [ -z "$DOMAIN_TLD" ] && [ -e "$SYSDB" ]; then
    DOMAIN_TLD=$(normalize_fqdn "$(sqlite3 "$SYSDB" "SELECT domain FROM globals WHERE domain IS NOT NULL AND domain != '' LIMIT 1" 2>/dev/null)")
fi
if [ -z "$DOMAIN_TLD" ] && [ -t 0 ]; then
    printf "Domain apex / TLD (e.g. pbx3.com) [pbx3.com]: " >&2
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
    # Ensure Asterisk config files in ASTLOCALCONF are symlinked into ASTPATH (manager.conf, pjsip.conf, etc.)
    php $SYSPATH/php/utilities/runLinker.php 2>/dev/null || true
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
    # Explicit host migration only: INSTANCE_FQDN=node.example.com PBX3_APPLY_INSTANCE_IDENTITY=1 installer.sh
    if [ "${PBX3_APPLY_INSTANCE_IDENTITY:-}" = "1" ] && valid_fqdn "$_LEGACY_FQDN"; then
        INSTANCE_SUBDOMAIN=$(echo "$_LEGACY_FQDN" | cut -d. -f1)
        DOMAIN_TLD=$(echo "$_LEGACY_FQDN" | cut -d. -f2-)
        INSTANCE_FQDN="$_LEGACY_FQDN"
        echo "PBX3_APPLY_INSTANCE_IDENTITY=1: applying INSTANCE_FQDN=$INSTANCE_FQDN"
        _APPLY_IDENT=1
    fi
fi

# Store instance domain + FQDN in globals; hostname = subdomain (fresh build or explicit migrate)
if [ "$_APPLY_IDENT" -eq 1 ] && [ -n "$INSTANCE_FQDN" ] && [ -n "$DOMAIN_TLD" ] && [ -n "$INSTANCE_SUBDOMAIN" ]; then
    _sql_dom=$(echo "$DOMAIN_TLD" | sed "s/'/''/g")
    _sql_fq=$(echo "$INSTANCE_FQDN" | sed "s/'/''/g")
    sqlite3 $SYSDB "UPDATE globals SET domain='$_sql_dom', fqdn='$_sql_fq', shortuid='$(echo "$INSTANCE_SUBDOMAIN" | sed "s/'/''/g")' WHERE rowid=(SELECT rowid FROM globals LIMIT 1);"
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

# Run setip once (network detection, shorewall/fail2ban/Asterisk localnet, /etc/issue)
# Previously a systemd oneshot at boot; we run it here so the installer does not depend on it.
echo running setip to resolve IP addresses
/usr/bin/php $SYSPATH/php/utilities/setip.php
# Remove the systemd unit so it is not loaded at boot (setip is run once by the installer only)
systemctl disable debsetlan.service 2>/dev/null || true
rm -f /etc/systemd/system/debsetlan.service
systemctl daemon-reload 2>/dev/null || true

# Shorewall6 setup (create /etc/shorewall6 if missing so service can start)
if [ -d "$SYSPATH/etc/shorewall6" ]; then
    mkdir -p /etc/shorewall6
    cp -f $SYSPATH/etc/shorewall6/rules /etc/shorewall6
    [ -f /etc/default/shorewall6 ] && sed -i 's/startup=0/startup=1/' /etc/default/shorewall6
    for file in $(ls $SYSPATH/etc/shorewall6/); do
        [ ! -e "/etc/shorewall6/$file" ] && cp -f "$SYSPATH/etc/shorewall6/$file" /etc/shorewall6
    done
    [ -f /etc/shorewall6/pbx3_rules6 ] && chown www-data:www-data /etc/shorewall6/pbx3_rules6
fi

#run shorewall's own fix routines
shorewall update

# F2b setup — Ubuntu 24.04 LTS (jail.d fragments; do not symlink jail.local)
ln -sf $SYSPATH/etc/fail2ban/action.d/shorewall.local /etc/fail2ban/action.d/shorewall.local
mkdir -p /etc/fail2ban/jail.d
if [ -L /etc/fail2ban/jail.local ] && [ "$(readlink /etc/fail2ban/jail.local 2>/dev/null)" = "$SYSPATH/etc/fail2ban/jail.local" ]; then
	rm -f /etc/fail2ban/jail.local
fi
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

# enable shorewall
[ -e $SHOREWALL/routestopped ] && mv $SHOREWALL/routestopped $SHOREWALL/routestopped.bak
systemctl enable shorewall.service
systemctl enable shorewall6.service

systemctl start shorewall.service
systemctl start shorewall6.service


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