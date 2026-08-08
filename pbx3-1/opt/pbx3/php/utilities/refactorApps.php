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
