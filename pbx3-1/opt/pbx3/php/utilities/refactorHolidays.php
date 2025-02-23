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

if (file_exists(__DIR__ . "/.refactorHolidayDone")) {
    echo "Holiday refactor alredy done for this Database";
    return 0;
} 

//
//  Clean up the holidays 
//

$holidays = $helper->getTable("holiday");
$tuple = array();
foreach ($holidays as $holiday) {
    $routeclass = $holiday['routeclass'];
    $route = $holiday['route'];
    $dialstring = null;
    $returnkey=null;
    $msg=null;
    $rc=null;
    $helper->getDirectDial($route,$routeclass,$dialstring,$msg,$rc);
    if (empty($dialstring)) {
        $dialstring = 'None';
    }
    $sql = $dbh->prepare("UPDATE holiday SET route=? WHERE pkey=?");
    $sql->execute(array($dialstring,$holiday['pkey']));
}

/*** close the database connection ***/
$dbh = null; 
/**
 * Mark the job as done
 */
$Holidaysdone = __DIR__ . "/.refactorHolidaysDone";
fopen($Holidaysdone,"w") 
    or die( "couldn't open $Holidaysdone");

?>		
