#!/bin/bash

. /opt/pbx3/scripts/bashconfig

setvcl() {
# turn on VCL in Globals
    echo "AWS instance detected, setting cloud flags"
    /usr/bin/sqlite3 $SYSDB "update globals set VCL=1"
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

chown -R www-data:www-data $SYSPATH/www
chown -R www-data:www-data $SYSPATH/db
chown -R www-data:www-data $SYSPATH/cache

chown -R asterisk:asterisk $ASTPATH/*
chown -R asterisk:asterisk /var/lib/asterisk
chown -R asterisk:asterisk /usr/share/asterisk/sounds
chown -R asterisk:asterisk /var/log/asterisk
chown -R asterisk:asterisk /var/spool/asterisk

chmod 664 -R $ASTPATH/*
chmod +x $ASTPATH/manager.d
chmod 755 -R $SYSPATH/www
chmod 755 -R $SYSPATH/generator
chmod 755 -R $SYSPATH/scripts
 
chmod +x $SYSPATH/service/sys-ua-helper/run 
chmod +x $SYSPATH/service/sys-ua-responder/run
chmod +x $SYSPATH/service/sys-ua-siplog/run


# link the helpers if they don't exist 
[ ! -L /etc/service/sys-ua-helper ] && ln -s $SYSPATH/service/sys-ua-helper /etc/service
[ ! -L /etc/service/sys-ua-responder ] && ln -s $SYSPATH/service/sys-ua-responder /etc/service
[ ! -L /etc/service/sys-ua-siplog ] && ln -s $SYSPATH/service/sys-ua-siplog /etc/service

# 
# deal with Apache
# 

# disable defaults
a2dissite 000-default
a2dissite default-ssl.conf

# set the key permissions so Apache and Asterisk can read the key
chmod 751 /etc/ssl/private
usermod -a -G ssl-cert www-data
usermod -a -G ssl-cert asterisk

# remove any previous sark references
rm -rf /etc/apache2/sites-enabled/sark*
rm -rf /etc/apache2/sites-available/sark*

# link our sites
[ ! -L /etc/apache2/sites-available/sark-certs.conf ] && ln -s $SYSPATH/etc/apache2/sites-available/sark-certs.conf /etc/apache2/sites-available
[ ! -L /etc/apache2/sites-available/sark-default-ssl.conf ] && ln -s $SYSPATH/etc/apache2/sites-available/sark-default-ssl.conf /etc/apache2/sites-available
[ ! -L /etc/apache2/sites-available/sark-http.conf ] && ln -s $SYSPATH/etc/apache2/sites-available/sark-http.conf /etc/apache2/sites-available
[ ! -L /etc/apache2/sites-available/sark-name.conf ] && ln -s $SYSPATH/etc/apache2/sites-available/sark-name.conf /etc/apache2/sites-available
[ ! -L /etc/apache2/sites-available/sark-ssl.conf ] && ln -s $SYSPATH/etc/apache2/sites-available/sark-ssl.conf /etc/apache2/sites-available
[ ! -L /etc/apache2/sites-available/sark-prov-ssl.conf ] && ln -s $SYSPATH/etc/apache2/sites-available/sark-prov-ssl.conf /etc/apache2/sites-available

# Use our versions of asterisk/modules, asterisk/http & asterisk/pjsip

[ ! -e $ASTPATH/modules.install.conf ] && mv $ASTPATH/modules.conf $ASTPATH/modules.install.conf
[ ! -L $ASTPATH/modules.conf ] && ln -s $ASTPATH/sark_modules.conf $ASTPATH/modules.conf
[ ! -e $ASTPATH/http.install.conf ] && mv $ASTPATH/http.conf $ASTPATH/http.install.conf
[ ! -L $ASTPATH/http.conf ] && ln -s $ASTPATH/sark_http.conf $ASTPATH/http.conf
[ ! -e $ASTPATH/pjsip.install.conf ] && mv $ASTPATH/pjsip.conf $ASTPATH/pjsip.install.conf
[ ! -L $ASTPATH/pjsip.conf ] && ln -s $ASTPATH/sark_pjsip.conf $ASTPATH/pjsip.conf


# enable sark apache fragments
a2ensite sark-http
a2ensite sark-ssl
a2ensite sark-name

# enable sark opional fragments for certificates 
if [ -e /etc/ssl/certs/ssl-cert-sark-customer.pem ]; then
    a2ensite sark-certs
    a2dissite sark-default-ssl
else 
    a2ensite sark-default-ssl
fi

if [ -e /etc/ssl/3pcerts/3pcerts.pem ]; then
    a2ensite sark-prov-ssl
else 
    a2dissite sark-prov-ssl
fi

#HTTPD
a2enmod rewrite > /dev/null 2>&1
a2enmod proxy > /dev/null 2>&1
a2enmod proxy_http > /dev/null 2>&1

#HTTPS
a2enmod ssl

#enable listening on IPV6 for apache
sed -i 's/Listen 80/Listen [::]:80/' /etc/apache2/ports.conf
sed -i 's/Listen 443/Listen [::]:443/' /etc/apache2/ports.conf

[ ! -e /etc/ssl/3pcerts ] && mkdir /etc/ssl/3pcerts 

systemctl enable apache2.service
systemctl stop apache2.service
systemctl start apache2.service


#handle multiple NICs
if [ ! -e /etc/network/interfaces.d ]; then
    mkdir -p /etc/network/interfaces.d
    echo "source /etc/network/interfaces.d/*" >> /etc/network/interfaces
fi
    
# set correct Asterisk dateformat in logger.conf
sed -i 's/^;dateformat=%F %T /dateformat=%F %T/' $ASTPATH/logger.conf
# set security logging for Ast11 
sed -i '/^messages/c \messages => security,notice,warning,error' $ASTPATH/logger.conf;
/usr/sbin/asterisk -rx 'logger reload'

#Shorewall setup
if [ -d $SHOREWALL ]; then
    sed -i 's/startup=0/startup=1/' /etc/default/shorewall
    sed -i "/^SAVE_IPSETS/c\SAVE_IPSETS=Yes" $SHOREWALL/shorewall.conf
    echo 'INCLUDE local.lan' > $SHOREWALL/params
    echo 'INCLUDE local.if1' >> $SHOREWALL/params

    cp -f $SYSPATH$SHOREWALLrules $SHOREWALL
    [ ! -e $FW_RULES ] && cp $FW_RULES $SHOREWALL
    #for pre 5.x upgrades check that 443 is open (otherwise they won't be able to login)
    grep  -q "tcp\s*443\s*" $FW_RULES
    if [  "$?" -ne "0" ] ; then
        echo ACCEPT net:\$LAN \$FW tcp 443 - - >> $FW_RULES 
    fi
    touch $SHOREWALL/$SYSPREFIX_inline_fqdn
    touch $SHOREWALL/$SYSPREFIX_inline_limit
    chown www-data:www-data $FW_RULES
    chown www-data:www-data $SHOREWALL/$SYSPREFIX_inline_fqdn
    chown www-data:www-data $SHOREWALL/$SYSPREFIX_inline_limit
fi

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
    chown www-data:www-data /etc/shorewall6/$SYSPREFIX_rules6
fi

#run shorewall's own fix routines
shorewall update

# F2b setup
[ -e /etc/fail2ban/jail.local ] && rm -rf /etc/fail2ban/jail.local && echo "replacing F2B jail.local" 
ln -s $SYSPATH/etc/fail2ban/jail-stretch.local /etc/fail2ban/jail.local
[ ! -e /etc/fail2ban/action.d/shorewall.local ] && [ -e $SYSPATH/etc/fail2ban/action.d/shorewall-jessie.local ] && ln -s $SYSPATH/etc/fail2ban/action.d/shorewall-jessie.local /etc/fail2ban/action.d/shorewall.local


# Asterisk 11+ call parks
[ ! -e $ASTPATH/res_parking.conf ] && touch $ASTPATH/res_parking.conf
grep -q '#include sark_res_parking.conf' $ASTPATH/res_parking.conf
if [  "$?" -ne "0" ] ; then
    echo "#include sark_res_parking.conf" >> $ASTPATH/res_parking.conf
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
[ -e  $SHOREWALLroutestopped ] && mv $SHOREWALLroutestopped $SHOREWALLroutestopped.bak
systemctl enable shorewall.service
systemctl enable shorewall6.service


# suppress CDR menu generation for Deb 9 and ubuntu 
[ -e $SYSPATH/cache/1520813339.db_v4_admin_perms2 ] && mv $SYSPATH/cache/1520813339.db_v4_admin_perms2 $SYSPATH/always/



#Make the public directories if they aren't there
[ ! -d $SYSPATH/public ] && mkdir $SYSPATH/public && chown www-data:www-data $SYSPATH/public
[ ! -d $SYSPATH/public/aastra ] && mkdir $SYSPATH/public/aastra && chown www-data:www-data $SYSPATH/public/aastra
[ ! -d $SYSPATH/public/cisco ] && mkdir $SYSPATH/public/cisco && chown www-data:www-data $SYSPATH/public/cisco
[ ! -d $SYSPATH/public/panasonic ] && mkdir $SYSPATH/public/panasonic && chown www-data:www-data $SYSPATH/public/panasonic
[ ! -d $SYSPATH/public/polycom ] && mkdir $SYSPATH/public/polycom && chown www-data:www-data $SYSPATH/public/polycom
[ ! -d $SYSPATH/public/snom ] && mkdir $SYSPATH/public/snom && chown www-data:www-data $SYSPATH/public/snom
[ ! -d $SYSPATH/public/vtech ] && mkdir $SYSPATH/public/vtech && chown www-data:www-data $SYSPATH/public/vtech
[ ! -d $SYSPATH/public/yealink ] && mkdir $SYSPATH/public/yealink && chown www-data:www-data $SYSPATH/public/yealink

# call recording 
[ ! -d $SYSPATH/media/recordings/default ] && mkdir -p $SYSPATH/media/recordings/default


#stop and restart the helper to reset the socket
sv d sys-ua-helper
sleep 1
sv u sys-ua-helper

#add definitions to MySQL
mysql -u root < $SYSPATH/cache/cdr-mysql-setup.sql

#stop systemd.resolved - it interferes with dnsmasq
systemctl stop systemd-resolved
systemctl disable systemd-resolved
#restart dnsmasq
systemctl enable dnsmasq
systemctl restart dnsmasq

if [ -d $SYSPATH/recmnt ]; then 
    mkdir $SYSPATH/recmnt
    chown www-data:www-data $SYSPATH/recmnt
    chmod 664 $SYSPATH/recmnt
fi