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
 *  dumper
 *  dumps the target sqlitedb into a set of prefixed files.  
 *  It will obey drops set in the $drops array.   This allows the removal of columns
 *  which are no longer used.     
 */

 require_once __DIR__ . "/../config.php";

 /**
 *  Set the prefix to create test output.  Default setting is "/last_"
 */
$prefix='/last_';
$db = SYSDB;

$shortopts = "d::L::";

$longopts = array(
	"inputdb::",
	"prefix::",
);

$options = getopt($shortopts, $longopts);


	if (isset($options["inputdb"])) {
		if (!file_exists($options["inputdb"])) {
			echo "DB import file not found\n";
			exit;
		}
		$db = $options["inputdb"];
	}


	if (isset($options["prefix"])) {	
		if (preg_match("/^\/.*_$/",$options["prefix"])) {
			$prefix = $options["prefix"];
		}
		else {
			echo "Prefix must begin with a slash and end with _ \n";
			exit;
		}
	}
	if (isset($options["L"])) {	
		require_once __DIR__ . "/ignoresAndDropsLegacy.php";
		echo "Using Legacy Ignores and Drops \n";
	}
	else {
		require_once __DIR__ . "/ignoresAndDrops.php";
		echo "Using PBX3 Ignores and Drops \n";
	}


echo "Proceeding with db $db and prefix $prefix \n";


$sqlitedb = "sqlite:" . $db;
$cfgfilename=DBDUMPS . $prefix . 'create.sql';
$datafilename=DBDUMPS . $prefix . 'data.sql';
$tablesdirectory=DBTABLEDUMPS . $prefix .'tabledumps';
 	 		

	/**
	 * find_col
	 *
	 * @param string $col - column to drop
	 * @param string $tab - tablename
	 * @param string $dropstab - name of the drops array
	 * @return boolean true - found, false notfound
	 */
	function find_col($col,$tab,$dropstab) {
		foreach ($dropstab as $key => $row) {
			if (strtolower($key) == strtolower($tab)) {
				if (in_array($col,$row)) {
					return true;
				}
			}
			
		}
		return false;
	}

	$tables=array();
	$colrows=array();
	$datarows=array();
		
    /*** connect to SQLite database ***/
    try {
		$dbh = new PDO($sqlitedb);
	}
	catch (Exception $e) {
		echo "Oops failed to open $sqlitedb" . " $e\n";
		exit(4);
	}

    /*** set the error reporting attribute ***/
    $dbh->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
 	$COLDATA 	= NULL;
	$VALDATA 	= NULL;
	$CREATE 	= "BEGIN TRANSACTION;\n";
	$INSERT 	= "BEGIN TRANSACTION;\n";
	$TABLEINSERT = "BEGIN TRANSACTION;\n";
	$CUSTDEVINSERT 	= "BEGIN TRANSACTION;\n";

// create the tablesdirectory if it does not exist
	if (is_dir($tablesdirectory)) {
		`rm -rf $tablesdirectory`;
	}
	`mkdir -p $tablesdirectory`; 

/*
 * get a list of tables
 */
    try { 
		$tables = $dbh->query("select name from sqlite_master where type='table'")->fetchall();
	}
	catch (Exception $e) {
		echo "Oops on table list fetch " . " $e\n";
		exit(8);
	}

/*
 * get a column list for each table
 */		
	foreach ($tables as $table) {
/**
 *  Ignore tables in the ignore list
 */
	if (in_array($table['name'],$ignores)) {
		echo "Ignoring table " . $table['name'] . "\n";
		continue;
	}
/*
 * get the create sql from sqlite3
 */
		try {
		 $sql = $dbh->query("select sql from sqlite_master WHERE name='" . $table['name'] . "' AND type='table'" )->fetchColumn();
		}
		catch (Exception $e) {
			echo "Oops on sql retrieve for " . $table['name'] . " $e\n";
			exit(12);
		}
		
//  make it idempotent
		if (!preg_match ('/^CREATE TABLE IF NOT EXISTS/', $sql)) {
			$sql = preg_replace ( '/^CREATE TABLE /','CREATE TABLE IF NOT EXISTS ', $sql );
		}
		$CREATE .= $sql; 
		$CREATE .= ";\n\n";
		
//  ignore empty tables
		$res = $dbh->query('select count(*) from ' . $table['name'] )->fetchColumn();
		if ( $res == 0 ) {
			$someText = "TABLE " . $table['name'] . " IS EMPTY";
			syslog(LOG_WARNING, date("M j H:i:s") . ": SYSDUMPER -> " . $someText . "\n");
			continue;
		}

//  get column metadata and table data 	
		try {
			$colrows = $dbh->query( "PRAGMA table_info(" . $table['name'] . ")" )->fetchall();
			$rows = $dbh->query( "SELECT * from " . $table['name'] )->fetchall();
		}
		catch (Exception $e) {
			echo "Oops on select from " . $table['name'] . " $e\n";
			exit(16);
		}
					
// Build the dump string 	
		foreach ($rows as $row) {	
			$tabname = 	$table['name'];
			
			foreach ($colrows as $col) {
// Deal with KSUIDs - allocate a ksuid to any table with an id column (unless its an autoincrement ID or it already has a ksuid)
				if ($col['name'] == 'id') {
// Check for autoincrement
					if (!preg_match ('/autoincrement/', $sql)) {
// Check format - we don't want to overwrite a previously issued ksuid
						if (!preg_match("/^[a-zA-Z0-9]{27}$/",$row[$col['name']])) {
// set the ksuid
							$row[$col['name']] = trim(`ksuid`);	
						}					
					}
				} 
				$myData = $row[$col['name']];
				$myCol = $col['name'];
				if 	( find_col($myCol,$tabname,$drops))	{				
					echo "dropped column " . $col['name'] . 
					" from table " . $table['name'] . "\n";
					continue;
				}
				if ($myData) {
// don't carry forward the create/update time stamps.  They'll cause interlocks on the DB.
					if ( !preg_match (" /^z_/", $col['name'] )) {				
							$COLDATA .= $col['name'] . ",";
							$VALDATA .= "'" . $myData . "',";
					}
				}
			}
			$COLDATA = rtrim($COLDATA, ',');
			$VALDATA = rtrim($VALDATA, ',');
			

// dump the customer data 

			$INSERT .= "INSERT OR IGNORE INTO " . $table['name'] . "(" . $COLDATA . ") values (" . $VALDATA . ");\n";
			$TABLEINSERT .= "INSERT OR IGNORE INTO " . $table['name'] . "(" . $COLDATA . ") values (" . $VALDATA . ");\n";
	
			$COLDATA = NULL;
			$VALDATA = NULL;			
		}	
		$TABLEINSERT 	.= "COMMIT;\n";
		$tname = $tablesdirectory . '/' . $table['name'];
		$fh = fopen($tname, 'w') or die('Could not open $tname!');
		fwrite($fh,$TABLEINSERT) or die('Could not write to $tname');
		fclose($fh);	
		`dos2unix $tname >/dev/null 2>&1`;
		$TABLEINSERT = "BEGIN TRANSACTION;\n";
	}

	$CREATE 	.= "COMMIT;\n";
	$INSERT 	.= "COMMIT;\n";
	
	$fh = fopen($cfgfilename, 'w') or die('Could not open file!');
	fwrite($fh,$CREATE) or die('Could not write to cfg file');
	fclose($fh);

	$fh = fopen($datafilename, 'w') or die('Could not open file!');
	fwrite($fh,$INSERT) or die('Could not write to insert file');
	fclose($fh);	

// clear any junk left by windows-based data changes 
	`dos2unix $cfgfilename >/dev/null 2>&1`;
	`dos2unix $datafilename >/dev/null 2>&1`;

	