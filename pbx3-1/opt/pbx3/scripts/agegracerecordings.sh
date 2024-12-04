#!/bin/bash
#
# delete grace recordings older than $RECGRACE days
# 

RECGRACE=`/usr/bin/sqlite3 /opt/sark/db/sark.db "select RECGRACE from globals;"`

find /opt/sark/media/recordings/deletes  -mtime +$RECGRACE -type f -exec rm -rf {} +
