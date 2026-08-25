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

# Fail closed before any dump/delete when -L prerequisites are missing.
if [ "$legacy" = "true" ]; then
	if [ ! -f "$LEGACY_DB" ]; then
		echo "ERROR: reloader -L needs $LEGACY_DB"
		echo "Legacy create schema is not shipped in the pbx3 package."
		echo "Private migrate tooling may stage it under db_legacy_sql when needed."
		exit 3
	fi
fi

mkdir -p "$DBDUMPS"
if [ -e "$SYSDB" ] ; then
	echo "Saving existing database $SYSDB as $LASTDB"
	cp -a "$SYSDB" "$LASTDB"
	echo "Dumping customer data from $SYSDB"
	if [ "$legacy" = "true" ]; then
		php "$DUMPER" -L
	else
		php "$DUMPER"
	fi
	if [ $? -ne 0 ]; then
		echo "DUMP ERROR"
		exit 4
	fi
fi


echo "Deleting existing db $SYSDB"
rm -f "$SYSDB"


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
	echo "Creating new database $SYSDB from $INSTANCE_DB, $DEVICE_DATA, $LARAVEL_DB and $TENANT_DB"
	sqlite3 $SYSDB < $INSTANCE_DB
	[ -e "$DEVICE_DATA" ] && sqlite3 $SYSDB < $DEVICE_DATA
	sqlite3 $SYSDB < $LARAVEL_DB
	sqlite3 $SYSDB < $TENANT_DB
fi

#Load the system messages
if [ -e $SYSMSGDB ]; then
	echo Loading system messages
	sqlite3 $SYSDB < $SYSMSGDB
fi
echo Loading system device data
sqlite3 $SYSDB < $DBSQL/sqlite_device_data.sql

#Reload any saved customer data

if [ -e $Customerdata ]; then
	echo Loading customer data from $Customerdata
	sqlite3 $SYSDB < $Customerdata
fi

# Instance identity: globals.id = KSUID, globals.pkey = 'global' (row marker). Legacy DBs may only have KSUID in pkey.
GCOUNT=$(sqlite3 $SYSDB "SELECT COUNT(*) FROM globals;" 2>/dev/null || echo "0")
if [ "$GCOUNT" -eq 0 ]; then
	KSUID=$(ksuid 2>/dev/null)
	if [ -n "$KSUID" ]; then
		sqlite3 $SYSDB "INSERT INTO globals(id, pkey) VALUES ('$KSUID', 'global');"
		mkdir -p "$(dirname "$INSTANCEID")"
		echo "$KSUID" > "$INSTANCEID"
		echo "Set instance id (globals.id) to $KSUID"
	else
		echo "WARNING: ksuid not found (install package ksuid); inserting fallback row pkey 'global'" >&2
		sqlite3 $SYSDB "INSERT INTO globals(pkey) VALUES ('global');"
	fi
elif [ "$GCOUNT" -ge 1 ]; then
	INSTANCE_KSUID=$(sqlite3 $SYSDB "SELECT COALESCE(NULLIF(trim(id), ''), CASE WHEN length(trim(pkey)) = 27 THEN trim(pkey) ELSE '' END) FROM globals LIMIT 1;" 2>/dev/null)
	if [ -n "$INSTANCE_KSUID" ]; then
		mkdir -p "$(dirname "$INSTANCEID")"
		echo "$INSTANCE_KSUID" > "$INSTANCEID"
		echo "Instance id file: $INSTANCE_KSUID"
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

# id / pkey / shortuid (from fqdn when present); safe after every reload
if [ -x "$SCRIPTS/normalize-globals-identity.sh" ]; then
	/bin/sh "$SCRIPTS/normalize-globals-identity.sh" || true
fi

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


# Firewall status (UFW). Shorewall sanitizer retired (Phase 4).
if command -v ufw >/dev/null 2>&1; then
	echo "UFW status:"
	ufw status verbose | sed -n '1,40p' || true
else
	echo "WARNING: ufw not found"
fi

