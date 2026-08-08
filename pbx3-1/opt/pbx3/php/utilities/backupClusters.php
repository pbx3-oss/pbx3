<?php
// Copyright (c) KoKoKraft 2024
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

/**
 *  Backup builder
 *  splits the current (or given) DB into a bunch of "mini" DBs, one for each Tenant 
 *  then it calls the dumper for each DB
 *  finally, it gathers all the other stuff together and zips it  
 *     
 *  Prefer tenant:export (pbx3api artisan) for fleet moves — see TENANT_MIGRATION_RUNBOOK.md.
 */

 require_once __DIR__ . "/../config.php";

$bfolder = BACKUPS;
$sfolder = SNAPSHOTS;
$filterTenant = "";

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
		$filterTenant = $options["tenant"];
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
	$dbh->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
}
catch (Exception $e) {
	echo "Oops failed to open $sqlitedb" . " $e\n";
	exit(4);
}

/*
 * get a list of tenants
 */
try { 
	$tenants = $dbh->query("select id, shortuid, pkey from cluster")->fetchall(PDO::FETCH_ASSOC);
}
catch (Exception $e) {
	echo "Oops on tenant list fetch " . " $e\n";
	exit(8);
}
 
foreach($tenants as $tenantRow) {
// ignore the default tenant - it always belongs to the instance
	if ($tenantRow['pkey'] == "default") {
		continue;
	}
	if ($filterTenant !== "") {
		if ($filterTenant !== $tenantRow['id']
			&& $filterTenant !== $tenantRow['shortuid']
			&& $filterTenant !== $tenantRow['pkey']) {
			continue;
		}
	}
	$backupDb = establishTenantFolders($tenantRow['id']);
	createTenantMiniDb($dbh,$backupDb,$tenantRow);
}

exit;

/**
 * Resolve cluster identifiers stored in tenant rows (shortuid, legacy pkey, or KSUID).
 *
 * @param PDO $dbh
 * @param array $tenantRow cluster id/shortuid/pkey
 * @return array
 */
function clusterAliasesForTenant($dbh, $tenantRow) {
	$aliases = array();
	foreach (array('pkey', 'shortuid', 'id') as $col) {
		if (!empty($tenantRow[$col])) {
			$aliases[$tenantRow[$col]] = true;
		}
	}
	return array_keys($aliases);
}

/**
 * createTenantMiniDb
 *
 * @param handle $dbh - sqlite handle
 * @param string $backupDb - path to the backup db
 * @param array $tenantRow - cluster row (id, shortuid, pkey)
 * @return void
 * run a series of selections on the main db and insert them into the tenantdb
 * 
 */
function createTenantMiniDb($dbh,$backupDb,$tenantRow) {
/**
 * list of tables to split into each miniDb (no trunks — instance-owned)
 */
	$tablesToSplit = array(
		"agent",
		"appl",
		"cos",
		"dateseg",
		"greeting",
		"holiday",
		"inroutes",
		"ipphone",
		"ipphonecosopen",
		"ipphonecosclosed",
		"ivrmenu",
		"page",
		"meetme",
		"queue",
		"route"
	);

	$tenantId = $tenantRow['id'];
	$aliases = clusterAliasesForTenant($dbh, $tenantRow);
	$placeholders = implode(',', array_fill(0, count($aliases), '?'));

/**
 * first, attach the new target db to our session
 */
	echo "Attaching $backupDb to main DB \n";
	try {
		$dbh->query("ATTACH DATABASE '" . $backupDb . "' AS backup");
	}
	catch (Exception $e) {
		echo "Oops on tenantDb attach $e\n";
		exit(8);
	}

/**
 * 	Insert the cluster row upon which all the other table rows depend for their RI
 */
	try {
		$stmt = $dbh->prepare("INSERT INTO backup.cluster SELECT * from cluster WHERE id = ?");
		$stmt->execute(array($tenantId));
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
			$stmt = $dbh->prepare(
				"INSERT INTO backup.$table SELECT * from $table WHERE cluster IN ($placeholders)");
			$stmt->execute($aliases);
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
	echo "Created backup db $backupDb \n";
	touch($backupDb);
	chmod($backupDb,0664);
	$t3 = DBTENANTSQL;
	echo "loading initial sql from $t3 \n";
	system("sqlite3 $backupDb < $t3");	

	return $backupDb;
}
