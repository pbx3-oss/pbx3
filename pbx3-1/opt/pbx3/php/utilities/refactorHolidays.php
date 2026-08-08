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
