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

/**
 *  !!!!!!! NO LONGER NEEDED FOR PJSIP !!!!!!!!!
 */

require_once __DIR__ . "/../config.php";

try {
    /*** connect to SQLite database ***/

    $dbh = new PDO(SYSDB);

    /*** set the error reporting attribute ***/
    $dbh->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

//
//  SIP extensions (phones) fixup for V6
// 
	$sql = "SELECT * FROM ipphone ORDER BY pkey";
    foreach ($dbh->query($sql) as $row) {
    	$sipiaxfriend = $row['sipiaxfriend'];
    	if (! preg_match(' /nat=/ ', $sipiaxfriend)) {
    		$sipiaxfriend .= "\n" . 'nat=$nat';
    	}
    	
    	if (! preg_match(' /transport=/', $sipiaxfriend)) {
    		$sipiaxfriend .= "\n" . 'transport=$transport';
    	}
        if (! preg_match(' /encryption=/', $sipiaxfriend)) {
            $sipiaxfriend .= "\n" . 'encryption=$encryption';
        }        
    	if ($sipiaxfriend != $row['sipiaxfriend']) {
    		$sql = $dbh->prepare("UPDATE ipphone SET sipiaxfriend = ? WHERE pkey = ?");
    		$sql->execute(array($sipiaxfriend,$row['pkey']));
    	}
    }

    /*** close the database connection ***/
    $dbh = null;   
}  

catch(PDOException $e)
    {
    echo $e->getMessage();
    }    

?>		
