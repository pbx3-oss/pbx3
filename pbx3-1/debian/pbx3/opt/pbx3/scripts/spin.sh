#!/bin/bash
#
# Spin off a backup  
#
# !!!! NEEDS TO BE REWRITTEN FOR S3 WITH VERSIONING !!!!
#


#cp  -a $SYSDB $BACKUPS/$DBNAME.`date +%s`
#
#sysroot='/usr/share/' 

# Legacy sark backup code (commented out - replaced by pbx3 backup)
#/usr/sbin/slapcat > /tmp/sark.local.ldif 
#/usr/bin/zip -r /opt/sark/bkup/sarkbak.`date +%s`.zip /opt/sark/db/sark.db $sysroot/asterisk/sounds/usergreet* $sysroot/asterisk/moh-* /var/spool/asterisk/voicemail /etc/asterisk /etc/shorewall /tmp/sark.local.ldif  >/dev/null 2>&1
#if [  "$(ls -A /opt/sark/bkup)" ]; then
#   /bin/ls -t /opt/sark/bkup/* | /bin/sed -e '1,9d' | /usr/bin/xargs -d '\n' /bin/rm
#fi
#rm /tmp/sark.local.ldif
