<?php
//
// Developed by CoCo
//
// Copyright (C) 2012 CoCoSoft
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
// - this looks like an error . /opt/pbx3/scripts/bashconfig
// take pre 5.0 PBX rules and format to suit

$OUT = NULL;
$file = "/etc/shorewall/PBX_rules";

	if (!file_exists($file)) {
		die ("No PBX rules found");
	}

	$rec = file($file, FILE_IGNORE_NEW_LINES|FILE_SKIP_EMPTY_LINES) or die('Could not read file!');
	foreach ($rec as $row) {
		if (preg_match(" /^#|^\s*$/ ", $row)) {
			continue;
		}
		if (preg_match(" /#/ ", $row)) {
			$splitComments = explode("#",$row,2);
			$cols = explode(" ",$splitComments[0]);
		}
		else {
			$cols = explode(" ",$row);
		}
		if (empty($cols[5])) {
			$cols[5] = '-';
		}
		if (empty($cols[6])) {
			$cols[6] = '-';
		}
		$nl = implode(" ",$cols);
		$nl = trim($nl);
		$OUT .= $nl;
		
		if (!empty($splitComments[1])) {			
			$OUT .= ' # ' . trim($splitComments[1]);
		} 
		$OUT .= "\n";
		unset ($cols);	
		unset ($splitComments);	
	}
	
	$fh = fopen($file, 'w') or die('Could not open file!');
	fwrite($fh, $OUT) 
		or die('Could not write to file');
	fclose($fh);	