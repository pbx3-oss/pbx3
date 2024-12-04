<?php
// +-----------------------------------------------------------------------+
// |  Copyright (c) KoKoSoft 2005-10                                  |
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
// Calculate disk recording storage used by each tenant and store it into the tenant record
//

include("localvars.php");
$recvals = array();

try {
    /*** connect to SQLite database ***/

    $dbh = new PDO($sarkdb);

    /*** set the error reporting attribute ***/
    $dbh->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

//
//  Calculate space usage for each tenant
// 
	$sql = "SELECT * FROM cluster";
    foreach ($dbh->query($sql) as $row) {
        $recvals[ $row['pkey']] ['recused'] = 0;
        $cmd = 'du -ch /opt/sark/media/recordings/*/*' . $row['pkey'] . '*|grep -i total';
        $ret = `$cmd`;
        preg_match(" /^(\d*\.?\d[1,2]?\w)/ ",$ret,$matches); 
        if ($matches[1]) {
            $recvals[$row['pkey']] ['recused'] = $matches[1];
        }    	
    }
//
//  update the tenant rows with the latest usage values
//  
    foreach ($recvals as $key=>$item) {
        echo "key=$key,value=" . $item['recused'] ." \n";
        
        $res = $dbh->prepare("UPDATE cluster SET recused = ? WHERE pkey = ?");
        $res->execute(array($item['recused'],$key));

    }

    /*** close the database connection ***/
    $dbh = null;   
}  

catch(PDOException $e)
    {
    echo $e->getMessage();
    }    

?>		
