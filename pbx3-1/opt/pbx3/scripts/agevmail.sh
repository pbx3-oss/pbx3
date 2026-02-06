#!/bin/bash
#
# Delete opened voicemail older than globals['VMAILAGE'] days
#
ZERO=0
VMAILAGE=`/usr/bin/sqlite3 $SYSDB "SELECT vmailage FROM globals LIMIT 1"`
#echo deleting vmail older than $VMAILAGE days
if [ ! -z $VMAILAGE ]; then
	if [ $VMAILAGE -gt $ZERO ]; then
		logger "srkagevmail - Deleting vmail older than $VMAILAGE days"
		find /var/spool/asterisk/voicemail/default/*/Old -name "msg*" -type f -mtime +$VMAILAGE -exec rm {} \;
	else
		logger "srkagevmail - no vmail ageing (variable is zero)"
	fi
else
	logger "srkagevmail - no vmail ageing (variable is null)"
fi