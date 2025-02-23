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

require_once __DIR__ . "/../config.php";
require_once DBCLASS;
require_once HELPER;

$helper = new helper;
$dbh = DB::getInstance();

if (file_exists(__DIR__ . "/.refactorAppsDone")) {
    echo "Apps refactor alredy done for this Database";
    return 0;
} 

//
//  Clean up the apps 
//
$apps = $helper->getTable("appl");

foreach ($apps as $app) {
    if (! is_numeric($app['pkey'])) {
        $app['name'] = $app['pkey'];
    }

    do {
        $newkey = rand(50000,80000);            
    }
    while ($helper->checkXref($newkey,$app['cluster'])); 

    $sql = $dbh->prepare("UPDATE appl SET name=?,pkey=? WHERE pkey=?");
    $sql->execute(array($app['name'],$newkey,$app['pkey']));
}


/*** close the database connection ***/
$dbh = null; 
/**
 * Mark the job as done
 */
$Appsdone = __DIR__ . "/.refactorAppsDone";
fopen($Appsdone,"w") 
    or die( "couldn't open $Appsdone");

?>		
