<?php
// +-----------------------------------------------------------------------+
// |  Copyright (c)  2005-10                                  |
// +-----------------------------------------------------------------------+
// | This file is free software; you can redistribute it and/or modify     |
// | it under the terms of the GNU General Public License as published by  |
// | the Free Software Foundation; either version 2 of the License, or     |
// | (at your option) any later versio                                  |
// | This file is distributed in the hope that it will be useful           |
// | but WITHOUT ANY WARRANTY; without even the implied warranty of        |
// | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSSee the          |
// | GNU General Public License for more detail                         |
// +-----------------------------------------------------------------------+
// | Author: KoKoSoft                                                           |
// +-----------------------------------------------------------------------+
//
//

// This will patch the existing extensions and replace pickup and callgroup with their named equivalents
// It will also clean up greetings and queueus, giving them extension numbers if they don't already have them
// Finally, it will convert old callgroups to the newer Queue format
//

require_once __DIR__ . "/../config.php";
require_once DBCLASS;
require_once HELPER;

$helper = new helper;
$dbh = DB::getInstance();

 
if (file_exists(__DIR__ . "/.refactorQueuesDone")) {
    echo "Queues refactor already done for this Database \n\n";
    return 0;
} 


//
//  Clean up existing queues
//
$queues = $helper->getTable("queue");

foreach ($queues as $queue) {
    if (is_numeric($queue['pkey'])) {
        continue;
    }
    $queue['name'] = $queue['pkey'];
    if (!empty($queue['directdial'])) {
        $newkey = $queue['directdial'];
    }
    else {
        do {
            $newkey = rand(5000,8000);            
        }
        while ($helper->checkXref($newkey,$queue['cluster'])); 
    }
    
    $sql = $dbh->prepare("UPDATE queue SET name=?,pkey=? WHERE pkey=?");
    $sql->execute(array($queue['name'],$newkey,$queue['pkey']));
}

/**
 * Convert the old ringgroups to queues
 * The exception is Page group These get a bogus queue strategy of "page"
 * They will be handled seperately by the generator
 */

 $ringgroups = $helper->getTable("speed");
 $tuple = array();
 foreach ($ringgroups as $ringgroup) {
/**
 *  ignore RINGALL
 */
    if (!is_numeric($ringgroup['pkey'])) {
        continue;
    }
    echo 'considering ring group ' . $ringgroup['pkey'] . "\n";
    $tuple['id'] = $ringgroup['id'];
    $tuple['pkey'] = $ringgroup['pkey'];
    $tuple['cluster'] = $ringgroup['cluster'];
    $tuple['description'] = $ringgroup['longdesc'];
    $tuple['name'] = $ringgroup['pkey'];
    $tuple['devicerec'] = $ringgroup['devicerec'];
    $tuple['divert'] = $ringgroup['divert'];
    $tuple['members'] = $ringgroup['out'];
    $tuple['alertinfo'] = $ringgroup['speedalert'];
    switch($ringgroup['grouptype']) {
        case "Ring":
            $tuple['strategy'] = "ringall";
            break;
        case "Hunt":
            $tuple['strategy'] = "linear";
            break;
        case "Page":
            $tuple['strategy'] = "page";
        break;            
    }

    /**
     * Handle outcome and outcomerouteclass
    */

    $routeclass = $ringgroup['outcomerouteclass'];
    $route = $ringgroup['outcome'];
    $dialstring = null;
    $returnkey=null;
    $msg=null;
    $rc=null;
    $helper->getDirectDial($route,$routeclass,$dialstring,$msg,$rc);
    if (!empty($dialstring)) {
        $tuple['outcome'] = $dialstring;
    }
    else {
        $tuple['outcome'] = 'None';
    }
    $helper->createTuple("queue",$tuple,true,true);
    unset ($tuple);
  }

/**
 * Finally drop the old speed table
 */
$sql = $dbh->prepare("DROP TABLE IF EXISTS speed");
$sql->execute();

/*** close the database connection ***/
    $dbh = null; 
/**
 * Mark the job as done
 */
    $queuesdone = __DIR__ . "/.refactorQueuesDone";
    fopen($queuesdone,"w") 
        or die( "couldn't open $queuesdone");

return;