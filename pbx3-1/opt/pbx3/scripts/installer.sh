#!/bin/bash

. /opt/pbx3/scripts/bashconfig

# Need to create the work directories in etc/asterisk:-
# callparks, endpoints, iax_trunks, queues, trunks


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
[ -e $ASTPATH/manager.d ] && chmod +x $ASTPATH/manager.d
[ -d "$GENERATOR" ] && chmod -R 755 "$GENERATOR"
chmod 755 -R $SYSPATH/scripts
 
chmod +x $SYSPATH/service/sys-ua-helper/run 
chmod +x $SYSPATH/service/sys-ua-siplog/run


# link the helpers if they don't exist 
[ ! -L /etc/service/sys-ua-helper ] && ln -s $SYSPATH/service/sys-ua-helper /etc/service
[ ! -L /etc/service/sys-ua-siplog ] && ln -s $SYSPATH/service/sys-ua-siplog /etc/service

# HTTP server (nginx) and API site are installed by pbx3api; see pbx3api docs.
# Ensure Asterisk (and later www-data for pbx3api) can read TLS certs (e.g. Let's Encrypt).
chmod 751 /etc/ssl/private 2>/dev/null || true
usermod -a -G ssl-cert asterisk 2>/dev/null || true
usermod -a -G ssl-cert www-data 2>/dev/null || true

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

# Instance FQDN: prompt (or use INSTANCE_FQDN env); store in globals.fqdn and set hostname to 3LD
# e.g. node1.pbx3.com -> fqdn=node1.pbx3.com, hostname=node1
normalize_fqdn() {
    echo "$1" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]'
}
valid_fqdn() {
    [ -n "$1" ] && case "$1" in *.*) true ;; *) false ;; esac
}
if [ -n "$INSTANCE_FQDN" ]; then
    INSTANCE_FQDN=$(normalize_fqdn "$INSTANCE_FQDN")
    valid_fqdn "$INSTANCE_FQDN" || INSTANCE_FQDN=""
fi
if [ -z "$INSTANCE_FQDN" ] && [ -t 0 ]; then
    while true; do
        printf "Instance FQDN (e.g. node1.pbx3.com): " >&2
        read -r INSTANCE_FQDN
        INSTANCE_FQDN=$(normalize_fqdn "$INSTANCE_FQDN")
        if valid_fqdn "$INSTANCE_FQDN"; then
            break
        fi
        echo "Please enter a full FQDN (e.g. node1.pbx3.com)." >&2
    done
fi

# Regenerate bashconfig from config.php when PHP is available (package ships bashconfig so install works without PHP)
if command -v php >/dev/null 2>&1; then
    php $SYSPATH/php/utilities/genbashconfig.php 2>/dev/null || true
fi

# Create initial DB if missing (fresh install)
[ ! -e "$SYSDB" ] && /bin/sh $SCRIPTS/create.initial.db

#Rebuild the database
/bin/sh $SCRIPTS/reloader.sh
chmod 775 $DBPATH
chmod 664 $SYSDB

# Store instance FQDN in globals and set system hostname to 3LD (e.g. node1.pbx3.com -> hostname node1)
if [ -n "$INSTANCE_FQDN" ]; then
    sqlite3 $SYSDB "UPDATE globals SET fqdn='$(echo "$INSTANCE_FQDN" | sed "s/'/''/g")' WHERE pkey=(SELECT pkey FROM globals LIMIT 1);"
    INSTANCE_3LD=$(echo "$INSTANCE_FQDN" | cut -d. -f1)
    if [ -n "$INSTANCE_3LD" ]; then
        if /usr/bin/hostnamectl set-hostname "$INSTANCE_3LD" 2>/dev/null; then
            :
        else
            echo "$INSTANCE_3LD" > /etc/hostname
            hostname "$INSTANCE_3LD" 2>/dev/null || true
        fi
        # Update /etc/hosts so 127.0.1.1 points to the new hostname (replace existing or add)
        if [ -f /etc/hosts ]; then
            sed -i 's/^127\.0\.1\.1[[:space:]].*/127.0.1.1\t'"$INSTANCE_3LD"'/' /etc/hosts
            grep -q '^127\.0\.1\.1[[:space:]]' /etc/hosts || sed -i '2i 127.0.1.1\t'"$INSTANCE_3LD" /etc/hosts
        fi
        echo "Set globals.fqdn to $INSTANCE_FQDN and hostname to $INSTANCE_3LD"
    fi
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

# F2b setup — Ubuntu 24.04 LTS (idempotent: force symlinks)
ln -sf $SYSPATH/etc/fail2ban/jail.local /etc/fail2ban/jail.local
ln -sf $SYSPATH/etc/fail2ban/action.d/shorewall.local /etc/fail2ban/action.d/shorewall.local





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