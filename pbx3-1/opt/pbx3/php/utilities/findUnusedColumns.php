<?php
// Copyright (c) KoKoSoft 2005-10
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// find unused database columns - meeds to be tested

require_once __DIR__ . "/../config.php";
     
$prefix='/finder_'; 

if (isset ($argv[1])) {
	$db = $argv[1];
}

	$tables=array();
	$colrows=array();
	$datarows=array();

		
    /*** connect to SQLite database ***/
    try {
		$dbh = new PDO(SYSDB);
	}
	catch (Exception $e) {
		echo "Oops failed to open DB SYSDB" . " $e\n";
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
		if ($table['name'] == 'ipphonecosopen' || $table['name'] == 'ipphonecosclosed' 
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
			$grep = "grep -r '" . $col['name'] . "' PHPDIR | wc -l";
			$ret = rtrim(`$grep`);
			if ($ret == 0) {
				echo '"' . $col['name'] . '",' . "\n"; 
			}
		}		
	}
?>		
