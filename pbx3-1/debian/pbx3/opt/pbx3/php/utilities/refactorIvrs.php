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

/* Testing ONLY
if (file_exists(__DIR__ . "/.refactorIvrsDone")) {
    echo "Ivrs refactor already done for this Database";
    return 0;
} 
*/
//
//  Clean up the ivrs - we have to parse the ivrs twice.  The first time we set the new pkey in
//  the ivr table.  The second time we set the route, routeclass in the ivr options and, finally, the timeout route.
//
// echo "Phase 1 - set new pkey in ivr table \n";

$ivrs = $helper->getTable("ivrmenu");

foreach ($ivrs as $ivr) {
    if (! is_numeric($ivr['pkey'])) {
        $ivr['name'] = $ivr['pkey'];
        // get a new candidate key
        do {
            $newkey = rand(50000,59999);            
        }
        while ($helper->checkXref($newkey,$ivr['cluster']));

        //update the database
        $sql = $dbh->prepare("UPDATE ivrmenu SET name=?,pkey=? WHERE pkey=?");
        $sql->execute(array($ivr['name'],$newkey,$ivr['pkey'])); 
    }   
}

// echo "Phase 2 - set route and routeclass in ivr options \n";
$ivrs = $helper->getTable("ivrmenu");
foreach ($ivrs as $ivr) {
    $key=0;
    $limit = 12;
    while ($key < $limit) {
		$routeclass = "routeclass".$key;
        $route = "option". $key;
        $dialstring = null;
        $msg=null;
        $rc=null;
        $helper->getDirectDial($ivr[$route],$ivr[$routeclass],$dialstring,$msg,$rc);
    
        if (empty($dialstring)) {
            $key++;
            continue;
        }
        $update_str = "UPDATE ivrmenu SET $route=? WHERE pkey=?";
        $sql = $dbh->prepare($update_str);
        $sql->execute(array($dialstring,$ivr['pkey']));
        $key++;
    }

//echo "Phase 3 - set timeout route and routeclass in ivr options \n";
// set timout direct dial from timeoutrouteclass
    $dialstring = null;
    $msg=null;
    $rc=null;
    $helper->getDirectDial($ivr['timeout'],$ivr['timeoutrouteclass'],$dialstring,$msg,$rc);
    if (!empty($dialstring)) {
        $update_str = "UPDATE ivrmenu SET timeout=? WHERE pkey=?";
        $sql = $dbh->prepare($update_str);
        $sql->execute(array($dialstring,$ivr['pkey']));
    }
}

/*** close the database connection ***/
$dbh = null; 
return 0; // testing ONLY
/**
 * Mark the job as done
 */
$Ivrsdone = __DIR__ . "/.refactorIvrsDone";
fopen($Ivrsdone,"w") 
    or die( "couldn't open $Ivrsdone");
fclose($Ivrsdone);

?>		
