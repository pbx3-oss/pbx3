<?php
// Copyright (c)  2005-10
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
