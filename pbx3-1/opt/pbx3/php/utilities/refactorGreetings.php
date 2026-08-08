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
