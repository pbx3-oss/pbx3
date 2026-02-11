#!/bin/bash

. /opt/pbx3/scripts/bashconfig

#echo "createdb is $CREATEDB"

Prefix="last_";


while getopts ":hsL" option; do
	case $option in
		h) # display Help
			echo "Syntax: reloader.sh [-s -d -h]"
			echo "s     source file prefixes."
#ToDo		echo "d     destination db."
			echo "L     create legacy destination db."
			echo "h     print this help."
			exit ;;

		s) # source files prefix
			Prefix=$OPTARG ;;

		L) # legacy
			legacy=true ;;

		\?) # Invalid option
			echo "Error: Invalid option: -$OPTARG"
			exit ;;
	esac
done

mkdir -p "$DBDUMPS"
echo "Saving existing database $SYSDB as $LASTDB"
cp -a $SYSDB $LASTDB


echo "Deleting existing db $SYSDB"
rm $SYSDB


Customerdata=$DBDUMPS/$Prefix
Customerdata="${Customerdata}data.sql"
echo "Building for target $SYSDB with data $Customerdata"

NEWINSTALL=true

sqlite3 $SYSDB 'PRAGMA synchronous=0;'
sqlite3 $SYSDB 'PRAGMA journal_mode=MEMORY;' >/dev/null 2>&1

if [ "$legacy" = "true" ]; then
	echo "L parameter given, creating $SYSDB from $LEGACY_DB"
	sqlite3 $SYSDB < $LEGACY_DB
else
	#create the db from the system files
	echo "Creating new database $SYSDB from $INSTANCE_DB, $LARAVEL_DB and $TENANT_DB"
	sqlite3 $SYSDB < $INSTANCE_DB
	sqlite3 $SYSDB < $LARAVEL_DB
	sqlite3 $SYSDB < $TENANT_DB
fi

#Load the system messages
if [ -e $SYSMSGDB ]; then
	echo Loading system messages
	sqlite3 $SYSDB < $SYSMSGDB
fi

#Reload any saved customer data

if [ -e $Customerdata ]; then
	echo Loading customer data from $Customerdata
	sqlite3 $SYSDB < $Customerdata
fi

# Instance identity: ensure globals has exactly one row with pkey = ksuid (idempotent: keep existing pkey if present)
GCOUNT=$(sqlite3 $SYSDB "SELECT COUNT(*) FROM globals;" 2>/dev/null || echo "0")
if [ "$GCOUNT" -ge 1 ]; then
	EXISTING_PKEY=$(sqlite3 $SYSDB "SELECT pkey FROM globals LIMIT 1" 2>/dev/null)
	if [ -n "$EXISTING_PKEY" ]; then
		mkdir -p "$(dirname "$INSTANCEID")"
		echo "$EXISTING_PKEY" > "$INSTANCEID"
		echo "Instance id already set (globals.pkey): $EXISTING_PKEY"
	fi
elif [ "$GCOUNT" -eq 0 ]; then
	KSUID=$(ksuid 2>/dev/null)
	if [ -n "$KSUID" ]; then
		sqlite3 $SYSDB "INSERT INTO globals(pkey) VALUES ('$KSUID');"
		mkdir -p "$(dirname "$INSTANCEID")"
		echo "$KSUID" > "$INSTANCEID"
		echo "Set instance id (globals.pkey) to $KSUID"
	else
		echo "WARNING: ksuid not found (install package ksuid); inserting fallback pkey 'global'" >&2
		sqlite3 $SYSDB "INSERT INTO globals(pkey) VALUES ('global');"
	fi
fi

#run the once files
if [ ! -e $SYSONCEDONE ] ; then
	echo Creating oncedone directory $SYSONCEDONE
	mkdir -p $SYSONCEDONE
fi


if [ -d "$SYSONCE" ]; then
	echo Running ONCE files..
	if [ "$(ls -A $SYSONCE)" ]; then
		for file in $(ls $SYSONCE/) ; do
			if [ ! -e $SYSONCEDONE/$file ]; then
				echo "Applying oncefile $file to $SYSDB"
				sqlite3 $SYSDB < $SYSONCE/$file
				cp -a $SYSONCE/$file $SYSONCEDONE/$file
			else
				echo "Skipping oncefile $file because it is already applied"
			fi
		done
	else
		echo "No ONCE files to apply - Directory is empty"
	fi
else
	echo "No ONCE Directory - skipping"
fi

#run the always files

if [ -d "$SYSALWAYS" ]; then
	echo Running ALWAYS files..
	if [ "$(ls -A $SYSALWAYS)" ]; then
		for file in $(ls $SYSALWAYS/) ; do
			echo "Applying alwaysfile $file to $SYSDB"
			sqlite3 $SYSDB < $SYSALWAYS/$file
		done
	else
		echo "No $SYSALWAYS files to apply - Directory is empty"
	fi
else
	echo "No ALWAYS Directory - skipping"
fi

sqlite3 $SYSDB 'PRAGMA synchronous=1;'
sqlite3 $SYSDB 'PRAGMA journal_mode=DELETE;' >/dev/null 2>&1

exit

# save a copy of the original installed database (for factory reset)
#[ "$NEWINSTALL" = true ] && cp $SYSDB $CLEANDB


#patch sipiaxfriend for nat and transport here using sipiaxfix
#echo Running V6 extension fixup
# FIX THIS!!!!!!!!!!!!!!!!!!!!!!!!!
# php $SIPFIX

# run the generator

if [ "$legacy" != "true" ]; then
	echo Running the Generator
	sh $GENAST
fi

#set db ownership
# HTTPOWNER (www-data) is the user that runs the HTTP server (Apache/nginx + PHP-FPM) for the API
chown $HTTPOWNER $DBPATH/*

#set db perms q
chmod 664 $SYSDB

exit 0

# clean the firewall up
echo Running firewall sanitizer
php $SYSPATH$GENERATOR/sanitize-firewall.php
echo Firewall rules are as follows
cat $FW_RULES
echo running firewall check
if sudo /sbin/shorewall check ;then
	echo "\nfirewall rules checked out OK...\n\n"
else
	echo "\nfirewall check failed with errors.  \nYou must correct the firewall rules!\n\n"
fi

