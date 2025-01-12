#!/bin/bash

. /opt/pbx3/scripts/bashconfig
[ ! -e $SYSDB ] && exit 4

/usr/bin/logger Regenerating Asterisk

php $ASTGEN

# copy the DB
/bin/cp $SYSDB $COPY_DB
/bin/mv $COPY_DB $READONLY_DB
#
/usr/bin/logger Regenerating Asterisk Finished
#/usr/bin/sqlite3 $SYSDB "UPDATE globals SET MYCOMMIT='NO' WHERE pkey='global';"
