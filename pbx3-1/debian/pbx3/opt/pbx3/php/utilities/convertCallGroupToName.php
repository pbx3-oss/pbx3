<?php
// +-----------------------------------------------------------------------+
// |  Copyright (c)  2005-10                                  |
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
//
// N.B. Run this from the generator directory
// This will patch the existing extensions and replace pickup and callgroup with their named equivalents
// Probs take a backup before you begin, huh?
//

require_once __DIR__ . "/../config.php";

try {
    /*** connect to SQLite database ***/

    $dbh = new PDO(SYSDB);

    /*** set the error reporting attribute ***/
    $dbh->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        
//
//  SIP extensions (phones)
//
	$sql = "SELECT * FROM IPphone order by pkey";
    foreach ($dbh->query($sql) as $row) {
    	$sipiaxfriend = $row['sipiaxfriend'];     
		$sipiaxfriend = preg_replace ( '/callgroup=\d+/', 'namedcallgroup=' . $row['cluster'], $sipiaxfriend);
		$sipiaxfriend = preg_replace ( '/pickupgroup=\d+/', 'namedpickupgroup=' . $row['cluster'], $sipiaxfriend);
		if ($sipiaxfriend != $row['sipiaxfriend']) {
    		$sql = $dbh->prepare("UPDATE ipphone SET sipiaxfriend=? WHERE pkey=?");
    		$sql->execute(array($sipiaxfriend,$row['pkey']));
    	}
	}
   
    /*** close the database connection ***/
    $dbh = null; 
}

catch(PDOException $e) {
    echo $e->getMessage();
}    

?>		
