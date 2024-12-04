#!/bin/bash

. /opt/gcs/scripts/bashconfig

echo "createdb is $CREATEDB"

Targetdb=$SYSDB
Fullpathtargetdb=$SYSDB
Fullpathlastdb=$LASTDB
Prefix="last_";


while getopts ":hs:d:" option; do
	case $option in
		h) # display Help
			echo "Syntax: reloader.sh [-s -d -h]"
			echo "s     source file prefixes."
			echo "d     destination db."
			echo "h     print this help."
			exit;;

		s) # source files prefix
			Prefix=$OPTARG;;
			
		d) # destination db
			Targetdb=$OPTARG;;
						
		\?) # Invalid option
			echo "Error: Invalid option"
			exit;;
	esac
done

if [ "$Targetdb" = "$SYSDB" ]; then
	echo "No -d parameter given, using $SYSDB as target"
else
	Fullpathtargetdb="$DBPATH/$Targetdb"
	Fullpathlastdb="$DBPATH/last_$Targetdb"	

	if [ -e "$Fullpathtargetdb" ]; then
		echo "Saving existing database as $Fullpathlastdb"
		cp -a $Fullpathtargetdb $Fullpathlastdb 
	else
		echo "Destination database $Fullpathtargetdb does not exist, creating it" 
		touch $Fullpathtargetdb
	fi
fi

echo "Saving existing database $Fullpathtargetdb as $Fullpathlastdb"
cp -a $Fullpathtargetdb $Fullpathlastdb 


echo "Deleting existing db $Fullpathtargetdb"
rm $Fullpathtargetdb

Customerdata=$DBPATH/$Prefix
Customerdata="${Customerdata}data.sql"
echo "Building for target $Fullpathtargetdb with data $Customerdata"

NEWINSTALL=true

sqlite3 $Fullpathtargetdb 'PRAGMA synchronous=0;'
sqlite3 $Fullpathtargetdb 'PRAGMA journal_mode=MEMORY;' >/dev/null 2>&1

#create the db from the system files
echo "Creating new database $Fullpathtargetdb from $CREATEDB"
sqlite3 $Fullpathtargetdb < $CREATEDB

#Load the system messages 
if [ -e $SYSMSGDB ]; then
	echo Loading system messages
	sqlite3 $Fullpathtargetdb < $SYSMSGDB
fi

#Reload any saved customer data

if [ -e $Customerdata ]; then
	echo Loading customer data from $Customerdata
	sqlite3 $Fullpathtargetdb < $Customerdata
fi


#run the once files
echo Running ONCE files..
if [ ! -e $SYSONCEDONE ] ; then
	echo Creating oncedone directory $STSONCEDONE
	mkdir $SYSONCEDONE
fi

if [ "$(ls -A $SYSONCE)" ]; then
	for file in $(ls $SYSONCE/) ; do
		if [ ! -e $SYSONCEDONE/$file ]; then
			echo "Applying oncefile $file to $Fullpathtargetdb"
			sqlite3 $Fullpathtargetdb < $SYSONCE/$file
			cp -a $SYSONCE/$file $SYSONCEDONE/$file
		else 
			echo "Skipping oncefile $file because it is already applied"
		fi	
	done
else 
	echo "No ONCE files to apply - Directory is empty"
fi

#run the always files
echo Running ALWAYS files..
if [ "$(ls -A $SYSALWAYS)" ]; then
	for file in $(ls $SYSALWAYS/) ; do
		echo "Applying alwaysfile $file to $Fullpathtargetdb"
		sqlite3 $Fullpathtargetdb < $SYSALWAYS/$file
	done
else 
	echo "No ALWAYS files to apply - Directory is empty"
fi

sqlite3 $Fullpathtargetdb 'PRAGMA synchronous=1;'
sqlite3 $Fullpathtargetdb 'PRAGMA journal_mode=DELETE;' >/dev/null 2>&1


# save a copy of the original installed database (for factory reset)
#[ "$NEWINSTALL" = true ] && cp $SYSDB $CLEANDB


#patch sipiaxfriend for nat and transport here using sipiaxfix
echo Running V6 extension fixup
# FIX THIS!!!
# php $SIPFIX

# run the generator
echo Running the Generator
sh $GENAST

#set db ownership
chown $HTTPOWNER $DBPATH/*

#set db perms q
chmod 664 $SYSDB

# clean the firewall up
echo Running firewall sanitizer
php /opt/sark/generator/sanitize-firewall.php
echo Firewall rules are as follows
cat /etc/shorewall/sark_rules
echo running firewall check
if sudo /sbin/shorewall check ;then
	echo "\nfirewall rules checked out OK...\n\n"
else
	echo "\nfirewall check failed with errors.  \nYou must correct the firewall rules!\n\n"
fi

