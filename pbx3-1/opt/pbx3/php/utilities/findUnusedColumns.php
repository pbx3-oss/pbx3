<?php
// +-----------------------------------------------------------------------+
// |  Copyright (c) KoKoSoft 2005-10                                  |
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
// | Author: KoKoSoft                                                           |
// +-----------------------------------------------------------------------+
// 

// find unused database columns - meeds to be tested

require_once __DIR__ . "/../config.php";
     
$prefix='/finder_'; 

$db = SYSDB;


if (isset ($argv[1])) {
	$db = $argv[1];
}

	$tables=array();
	$colrows=array();
	$datarows=array();

		
    /*** connect to SQLite database ***/
    try {
		$dbh = new PDO($db);
	}
	catch (Exception $e) {
		echo "Oops failed to open DB $sarkdb" . " $e\n";
		exit(4);
	}

    /*** set the error reporting attribute ***/
    $dbh->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

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
// ignore old tables and system tables		
		if ($table['name'] == 'IPphoneCOSopen'  ||  $table['name'] == 'IPphoneCOSclosed' 
		  || $table['name'] == 'UserPanel' 	||  $table['name'] == 'PanelGroupPanel'
		  || $table['name'] == 'IPphone_FKEY' ||  $table['name'] == 'Device_FKEY' 
		  || $table['name'] == 'tt_help_core' ||  $table['name'] == 'master_audit'
		  || $table['name'] == 'undolog' ||  $table['name'] == 'tt_help_user'
		  || $table['name'] == 'master_xref' ||  $table['name'] == 'vendor_xref') {

			continue;
	  	}

//  get column metadata and table data 	
		try {
			$colrows = $dbh->query( "PRAGMA table_info(" . $table['name'] . ")" )->fetchall();
			
		}
		catch (Exception $e) {
			echo "Oops on select from " . $table['name'] . " $e\n";
			exit(16);
		}
					
// Build the column list 
		echo "\n\n" . $table['name'] . "\n";			
		foreach ($colrows as $col) {
/**
 * 	ignore keys and timestamps
 */
			if ( preg_match (" /^z_/", $col['name'] )) {
				continue;
			}
			if ( preg_match (" /^pkey/", $col['name'] )) {
				continue;
			}
/**
 * 	lookup column name in drop list	
 */ 			
			$grep = "grep -r '" . $col['name'] . "' /opt/sark/php | wc -l";
			$ret = rtrim(`$grep`);
			if ($ret == 0) {
				echo '"' . $col['name'] . '",' . "\n"; 
			}
		}		
	}
?>		
