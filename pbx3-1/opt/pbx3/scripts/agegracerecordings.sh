#!/bin/bash
#
# delete grace recordings older than $RECGRACE days
# 

. /opt/pbx3/scripts/bashconfig

#
# no longer necessary with S3
# 

RECGRACE=`/usr/bin/sqlite3 $SYSDB "select recgrace from globals;"`

find $RECORDINGS$DELETES -mtime +$RECGRACE -type f -exec rm -rf {} +
