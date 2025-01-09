#!/bin/bash
#
# delete grace recordings older than $RECGRACE days
# 

#
# no longer necessary with S3
# 

RECGRACE=`/usr/bin/sqlite3 $SYSDB "select RECGRACE from globals;"`

find /opt/sark/media/recordings/deletes  -mtime +$RECGRACE -type f -exec rm -rf {} +
