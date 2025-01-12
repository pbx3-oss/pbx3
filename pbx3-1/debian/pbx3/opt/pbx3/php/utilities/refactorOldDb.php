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
// N.B. Run this from the generator directory
// This will patch the existing extensions and replace pickup and callgroup with their named equivalents
// It will also clean up greetings and queueus, giving them extension numbers if they don't already have them
// Finally, it will convert old callgroups to the newer Queue format
// Probs take a backup before you begin, huh?
//

require_once __DIR__ . "/../config.php";

require_once DBCLASS;
require_once HELPER;

$helper = new helper;
$dbh = DB::getInstance();

//
//  Clean up existing queues first
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
    $sql = $dbh->prepare("UPDATE greeting SET pkey=?,filename=? WHERE id=?");
    $sql->execute(array($matches[1],$filename,$greeting['id']));
}

//
//  Clean up the ivrs 
//
$ivrs = $helper->getTable("ivrmenu");

foreach ($ivrs as $ivr) {
    if (is_numeric($ivr['pkey'])) {
        continue;
    }
    $ivr['name'] = $ivr['pkey'];

    do {
        $newkey = rand(50000,80000);            
    }
    while ($helper->checkXref($newkey,$ivr['cluster'])); 

    
    $sql = $dbh->prepare("UPDATE ivrmenu SET name=?,pkey=? WHERE pkey=?");
    $sql->execute(array($ivr['name'],$newkey,$ivr['pkey']));
}

/**
 * Now convert the old ringgroups to queues
 * The exception is Page groups.  These get a bogus queue strategy of "page"
 * They will be handled seperately by the generator
 */


 $ringgroups = $helper->getTable("speed");
 $tuple = array();
 foreach ($ringgroups as $ringgroup) {
     $tuple['id'] = $ringgroup['id'];
     $tuple['pkey'] = $ringgroup['pkey'];
     $tuple['cluster'] = $ringgroup['cluster'];
     $tuple['description'] = $ringgroup['longdesc'];
     $tuple['name'] = "RingGroup" . $ringgroup['pkey'];
     $tuple['devicerec'] = $ringgroup['devicerec'];
     $tuple['divert'] = $ringgroup['divert'];
     $tuple['members'] = $ringgroup['out'];
     $tuple['outcome'] = $ringgroup['outcome'];
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
     
     $helper->createTuple("queue",$tuple,true,true);
     unset ($tuple);
 }

/*** close the database connection ***/
$dbh = null; 
  

?>		
