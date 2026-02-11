<?php
/**
 * Generate the bash config file from the php config
 * Run after changes to config.php
 * 
 * This script COMPLETELY REBUILDS bashconfig from config.php.
 * config.php is the source of truth - all constants defined there
 * will be written to bashconfig, overwriting any manual edits.
 */

require_once __DIR__ . "/../config.php";

$myconstants = get_defined_constants(true);

$OUT = NULL;
foreach ($myconstants as $key=>$groups) {
    if ($key != 'user') {
        continue;
    }
    foreach ($groups as $gkey=>$gmem) {
        $OUT .= "$gkey=$gmem\n";
    }
}

if (!empty($OUT)) {
    $fh = fopen(BASHCONFIG, 'w') or die("Could not open file " . BASHCONFIG .  "!!!");
    fwrite($fh, $OUT) or die("Could not write to file "  . BASHCONFIG .  "!!!");
    fclose($fh);
    echo "bashconfig regenerated from config.php\n";
} else {
    die("No user-defined constants found in config.php!\n");
}