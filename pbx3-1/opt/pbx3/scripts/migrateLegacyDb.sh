#!/bin/bash

. /opt/pbx3/scripts/bashconfig

sudo php $DUMPER -L
sudo sh $RELOADER -L

sudo sqlite3 $SYSDB < $DBPATH/db_legacy_sql/sqlite_fix_lineio.sql
sudo php $UTILITIES/refactorGreetings.php

sudo php $UTILITIES/refactorOldDB.php

sudo php $DUMPER
sudo rm $SYSDB

sudo sqlite3 $SYSDB < $DBSQL/sqlite_create_tenant.sql

sudo sqlite3 $SYSDB < $DBSQL/sqlite_create_instance.sql

sudo sh $RELOADER 

sudo sqlite3 $SYSDB < $DBPATH/db_legacy_sql/sqlite_fixRi.sql

sudo php $DUMPER 
sudo sh $RELOADER 
