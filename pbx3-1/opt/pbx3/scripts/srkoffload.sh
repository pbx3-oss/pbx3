#!/bin/bash
#
TARGET = `sqlite3 /opt/sark/db/sark.db "select RECMOUNT from globals"`

if mount | grep "on /opt/sark/media type" > /dev/null
then
 echo "media device is mounted OK"
 /usr/bin/rsync --remove-source-files /var/spool/asterisk/monout/* /media/usbdrive/sound/`date +%F`/
else
 mount $TARGET /opt/sark/media
 if mount | grep "on /opt/sark/media type type" > /dev/null
 then
   /usr/bin/rsync --remove-source-files /var/spool/asterisk/monout/* /media/usbdrive/sound`date +%F`/
 else
   echo "unable to mount disk - sync will use local folder"
 fi
fi
