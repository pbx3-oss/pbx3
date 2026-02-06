#!/bin/bash
#
# delete grace recordings older than $RECGRACE days
# 

. /opt/pbx3/scripts/bashconfig

#
# no longer necessary with S3
# 

RECGRACE=`/usr/bin/sqlite3 $SYSDB "SELECT recgrace FROM globals LIMIT 1"`

find $RECORDINGS$DELETES -mtime +$RECGRACE -type f -exec rm -rf {} +
