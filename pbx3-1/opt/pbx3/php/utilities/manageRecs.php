<?php
// Copyright (c) KoKoSoft 2005-10
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
// Calculate disk recording storage used by each tenant and store it into the tenant record
//

require_once __DIR__ . "/../config.php";
$recvals = array();

try {
    /*** connect to SQLite database ***/

    $dbh = new PDO(SYSDB);

    /*** set the error reporting attribute ***/
    $dbh->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

//
//  Calculate space usage for each tenant
// 
	$sql = "SELECT * FROM cluster";
    foreach ($dbh->query($sql) as $row) {
        $recvals[ $row['pkey']] ['recused'] = 0;
        $cmd = 'du -ch /opt/pbx3/media/recordings/*/*' . $row['pkey'] . '*|grep -i total';
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
