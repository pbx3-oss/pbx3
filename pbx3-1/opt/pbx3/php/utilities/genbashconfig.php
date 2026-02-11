<?php
/**
 * Generate the bash config file from the php config
 * Run after changes to config.php
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
}
$chmod  = "chmod +x " . BASHCONFIG;
`$chmod`;