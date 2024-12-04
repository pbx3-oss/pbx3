<?php
// +-----------------------------------------------------------------------+
// |  Copyright (c) KoKoKraft 2024
// +-----------------------------------------------------------------------+
// | This file is free software; you can redistribute it and/or modify     |
// | it under the terms of the GNU General Public License as published by  |
// | the Free Software Foundation; either version 2 of the License, or     |
// | (at your option) any later version.                                   |
// | This file is distributed in the hope that it will be useful           |
// | but WITHOUT ANY WARRANTY; without even the implied warranty of        |
// | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the          |
// | GNU General Public License for more details.                          |
// +-----------------------------------------------------------------------+
// | Author: KoKoKraft                                                      
// +-----------------------------------------------------------------------+
// 

/**
 *  Backup builder
 *  splits the current (or given) DB into a bunch of "mini" DBs, one for each Tenent 
 *  then it calls the dumper for each DB
 *  finally, it gathers all the other stuff together and zips it  
 *     
 */

 require_once __DIR__ . "/../config.php";

 /**
 *  Set the prefix to create the output.  Default setting is "/last_"
 */

$bfolder = BACKUPS;
$sfolder = SNAPSHOTS;
$tenant = "";


$shortopts = "";

$longopts = array(
	"inputdb::",
	"tenant::",
	"folder::"
);

$options = getopt($shortopts, $longopts);

if (in_array("inputdb",$options)) {
	if ($options["inputdb"]) {
		if (!file_exists($options["inputdb"])) {
			echo "DB import file not found\n";
			exit;
		}
		$db = $options["inputdb"];
	}
}

if (in_array("tenant",$options)) {
	if ($options["tenant"]) {	
		if (!preg_match("/^[a-zA-Z0-9]{27}$/",$options["tenant"])) {
			echo "Tenant format is not a valid KSUID - ^[a-zA-Z0-9]{27}\$ \n";
			exit;
		}
		$tenant = $options["tenant"];
	}
}

if (in_array("folder",$options)) {
	if ($options["folder"]) {
		if (!file_exists($options["folder"])) {
			echo "Target folder does not exist \n";
		}
		$folder = $options["folder"];
	}
}

//echo "Proceeding with db $db, tenant $tenant and folder $folder \n";


/**
 * Get a database connection to the source DB
 */
$sqlitedb = "sqlite:" . SYSDB;
/*** connect to SQLite database ***/
try {
	$dbh = new PDO($sqlitedb);
}
catch (Exception $e) {
	echo "Oops failed to open $sqlitedb" . " $e\n";
	exit(4);
}

/*
 * get a list of tenants
 */
try { 
	$tenants = $dbh->query("select id from cluster")->fetchall();
}
catch (Exception $e) {
	echo "Oops on tenant list fetch " . " $e\n";
	exit(8);
}
 
foreach($tenants as $tenant) {	
	$backupDb = establishTenantFolders($tenant['id']);
	echo "Created backup db $backupDb \n";
	createTenantMiniDb($dbh,$backupDb,$tenant['id']);
}

exit;

/**
 * createTenantMiniDb
 *
 * @param handle $dbh - sqlite handle
 * @param string $backupDb - path to the backup db
 * @param string $tenant - name of the tenant to backup
 * @return void
 * run a series of selections on the main db and insert them into the tenantdb
 * 
 */
function createTenantMiniDb($dbh,$backupDb,$tenant) {
/**
 * list of tables to split into each miniDb
 */
	$tablesToSplit = array(
		"agent",
		"appl",
		"cos",
		"dateseg",
		"greeting",
		"holiday",
		"ipphone",
		"ipphonecosopen",
		"ipphonecosclosed",
		"ivrmenu",
		"lineio",
		"page",
		"meetme",
		"queue",
		"route"
	);

/**
 * first, attach the new target db to our session
 */
	echo "Attaching $backupDb to main DB \n";
	try {
		$dbh->query("ATTACH DATABASE \"$backupDb\" AS backup");
	}
	catch (Exception $e) {
		echo "Oops on tenantDb attach $e\n";
		exit(8);
	}

/**
 * 	Insert the cluster row upon which all the other table rows depend for their RI
 */
	try {
		$dbh->query(
			"INSERT INTO backup.cluster SELECT * from cluster WHERE id='$tenant' ");
	}
	catch (Exception $e) {
		echo "Oops on tenant insert to backup DB $e\n";
		exit(8);
	}

/**
 *  Now we can iterate through $tablesToSplit applying our insert/select to each table
 */
	foreach($tablesToSplit as $key => $table ) {
		echo "table is $table \n"; 
		try {
			$dbh->query(
				"INSERT INTO backup.$table SELECT * from $table WHERE cluster='$tenant' ");
		}
		catch (Exception $e) {
			echo "Oops on $table insert $e\n";
			exit(8);
		}	
	}

/**
 * 	Detach the backup db ready for the next one
 */
	echo "Detaching $backupDb from main DB \n";
	try {
		$dbh->query("DETACH DATABASE backup");
	}
	catch (Exception $e) {
		echo "Oops on tenantDb detach $e\n";
		exit(8);
	}

	return;
}

 /**
  * establishTenantFolders
  *
  * @param string tenant name
  * @return new backup db name
  * 
  * create a tenant folder inside the bkup folder (if it doesn't already exist)
  * create a new epoch backup folder within each tenant folder
  * create an empty database within the epoch folder
  * 
  */
function establishTenantFolders($tenant) {

	/**
	 * create a backup folder for the tenant
	 */	
	$tenantdir = BACKUPS . "/" . $tenant;
	if (!file_exists($tenantdir)) {
		mkdir($tenantdir,0664);	
	}
	/**
	 * 	create an epoch directory for this backup run
	 */
	$epochTenantDir = $tenantdir . "/" . trim(`date +%s`);
	mkdir ($epochTenantDir,0664);
	/**
	 *  create a preloaded database within the epoch folder
	 */
	$backupDb = $epochTenantDir . "/sqlite.db";
	touch($backupDb);
	chmod($backupDb,0664);
	system("sqlite3 $backupDb < " . CREATEDB);	

	return $backupDb;
}

