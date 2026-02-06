#!/bin/bash

. /opt/pbx3/scripts/bashconfig

# Need to create the work directories in etc/asterisk:-
# callparks, endpoints, iax_trunks, queues, trunks


setvcl() {
# turn on VCL in Globals
    echo "AWS instance detected, setting cloud flags"
    /usr/bin/sqlite3 $SYSDB "update globals set vcl=1"
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
chmod 755 -R $SYSPATH/generator
chmod 755 -R $SYSPATH/scripts
 
chmod +x $SYSPATH/service/sys-ua-helper/run 
chmod +x $SYSPATH/service/sys-ua-siplog/run


# link the helpers if they don't exist 
[ ! -L /etc/service/sys-ua-helper ] && ln -s $SYSPATH/service/sys-ua-helper /etc/service
[ ! -L /etc/service/sys-ua-siplog ] && ln -s $SYSPATH/service/sys-ua-siplog /etc/service

# 
# deal with Apache (API only on 44300; no colocated admin UI)
# 

# disable default sites
a2dissite 000-default 2>/dev/null || true
a2dissite default-ssl.conf 2>/dev/null || true

# remove any previous sark/pbx3 site links (cleanup)
rm -f /etc/apache2/sites-enabled/sark*
rm -f /etc/apache2/sites-enabled/pbx3.conf
rm -f /etc/apache2/sites-available/sark*

# set key permissions so Apache and Asterisk can read certs
chmod 751 /etc/ssl/private
usermod -a -G ssl-cert www-data
usermod -a -G ssl-cert asterisk

# install pbx3 API site (only site we use)
if [ ! -e /etc/apache2/sites-available/pbx3.conf ]; then
    ln -s $SYSPATH/etc/apache2/sites-available/pbx3.conf /etc/apache2/sites-available/pbx3.conf
fi
# optional: install snakeoil cert fragment if we want to Include it from pbx3.conf later
if [ ! -e /etc/apache2/sites-available/pbx3-snakeoil.conf ]; then
    ln -s $SYSPATH/etc/apache2/sites-available/snakeoil-certs.conf /etc/apache2/sites-available/pbx3-snakeoil.conf 2>/dev/null || true
fi

# enable only the pbx3 API site (HTTPS on 44300)
a2ensite pbx3.conf

# required modules
a2enmod rewrite >/dev/null 2>&1
a2enmod ssl
a2enmod proxy >/dev/null 2>&1
a2enmod proxy_http >/dev/null 2>&1

# ensure port 44300 is allowed in ports.conf (pbx3.conf uses Listen [::]:44300)
if ! grep -q 'Listen.*44300' /etc/apache2/ports.conf 2>/dev/null; then
    echo "Listen [::]:44300" >> /etc/apache2/ports.conf
fi

systemctl enable apache2.service
systemctl stop apache2.service
systemctl start apache2.service

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

# Regenerate bashconfig from config.php (source of truth)
php $SYSPATH/php/utilities/genbashconfig.php 2>/dev/null || true

# Create initial DB if missing (fresh install)
[ ! -e "$SYSDB" ] && /bin/sh $SCRIPTS/create.initial.db

#Rebuild the database
/bin/sh $SCRIPTS/reloader.sh
chmod 775 $DBPATH
chmod 664 $SYSDB

# enable setlan
echo running setlan to resolve IP addresses
systemctl enable debsetlan.service
systemctl start debsetlan.service
sleep 10

#Shorewall6 setup
if [ -d /etc/shorewall6 ]; then
# the rules file always gets refreshed
# 
    cp -f $SYSPATH/etc/shorewall6/rules /etc/shorewall6
    sed -i 's/startup=0/startup=1/' /etc/default/shorewall6
    for file in `ls $SYSPATH/etc/shorewall6/` ; do
                [ ! -e /etc/shorewall6/$file ] && cp -f $SYSPATH/etc/shorewall6/$file /etc/shorewall6            
    done    
    chown www-data:www-data /etc/shorewall6/pbx3_rules6
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


# suppress CDR menu generation for Deb 9 and ubuntu 
[ -e $SYSPATH/cache/1520813339.db_v4_admin_perms2 ] && mv $SYSPATH/cache/1520813339.db_v4_admin_perms2 $SYSPATH/always/


# call recording 
[ ! -d $SYSPATH/media/recordings/default ] && mkdir -p $SYSPATH/media/recordings/default


#stop and restart the helper to reset the socket
sv d sys-ua-helper
sleep 1
sv u sys-ua-helper

#add definitions to MySQL (if MySQL is installed)
command -v mysql >/dev/null 2>&1 && mysql -u root < $SYSPATH/cache/cdr-mysql-setup.sql 2>/dev/null || true

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