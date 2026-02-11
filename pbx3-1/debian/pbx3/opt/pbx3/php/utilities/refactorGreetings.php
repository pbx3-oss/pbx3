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

//

require_once __DIR__ . "/../config.php";
require_once DBCLASS;
require_once HELPER;

$helper = new helper;
$dbh = DB::getInstance();

if (file_exists(__DIR__ . "/.refactorGreetingsDone")) {
    echo "Greetings refactor alredy done for this Database \n\n";
    return 0;
}

/**
 *  Clean up greetings
 *  pkey moves to filename
 *  pkey becomes /\d{4}$/
 *  
 */
$greetings = $helper->getTable("greeting");


foreach ($greetings as $greeting) {
    if (is_numeric($greeting['pkey'])) {
        continue;
    }
    $filename = $greeting['pkey'];
    preg_match('/.*(\d{4})$/',$greeting['pkey'],$matches);
    if (!is_numeric($matches[1])) {
        echo "Greeting pkey last 4 not numeric - ignoring for " .  $greeting['pkey'] . "\n";
        continue;
    } 
//    echo "matches is " . $matches[1] . "\n";
    $sql = $dbh->prepare("UPDATE greeting SET pkey=?,filename=? WHERE pkey=?");
    $sql->execute(array($matches[1],$filename,$filename));
}

/*** close the database connection ***/
$dbh = null; 
/**
 * Mark the job as done
 */
$Greetingsdone = __DIR__ . "/.refactorGreetingsDone";
fopen($Greetingsdone,"w") 
    or die( "couldn't open $Greetingsdone");
    
return;		
