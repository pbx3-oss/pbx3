#!/bin/bash

. /opt/pbx3/scripts/bashconfig

sudo rm -rf $SYSPATH/oncedone/*
sudo rm -rf $UTILITIES/.refactor*

#run dump/reload in legacy mode first to convert old data
sudo php $DUMPER -L
sudo sh $RELOADER -L

#split lineio into inroutes and trunks
sudo sqlite3 $SYSDB < $DBSQL/sqlite_fix_lineio.sql

#refactor various data structures
sudo php $UTILITIES/refactorGreetings.php
sudo php $UTILITIES/refactorApps.php

#convert all of the old speed dials to the new queue structure
sudo php $UTILITIES/refactorQueues.php

sudo php $UTILITIES/refactorIvrs.php
sudo php $UTILITIES/refactorHolidays.php

#run dump/reload again in current mode to apply refactors
sudo php $DUMPER
sudo sh $RELOADER 

#run dump/reload with all new structure and apply things like shortuids
sudo php $DUMPER
sudo sh $RELOADER

# fix RI across the db
sudo sqlite3 $SYSDB  < $DBSQL/sqlite_fixRi.sql

#dump and reload one last time to ensure RI is saved to last_db
sudo php $DUMPER 
sudo sh $RELOADER 
