<?php

// rewrite ldap ldif records with the 6.2 style dn of the form dn: uid={uid},ou={tenant},ou={contacts}.BASE

// Set these according to the input/output needs
$base = "dc=ec2,dc=internal";
$iFile = "ldapbkup.workcopy.ldif";
$ou = "ou=default,ou=Contacts,";


$handle = @fopen($iFile, "r") or die('Could not read file!');
if ($handle) {
    while (($buffer = fgets($handle, 4096)) !== false) {
        if (!preg_match(' /^dn:\s+cn=/ ',$buffer)) {
                echo $buffer;
                continue;
        }
        echo "dn: uid=" . uniqid('',true) . $ou  . $base ."\n";;
    }
}
if (!feof($handle)) {
        echo "Error: unexpected fgets() fail\n";
    }
    fclose($handle);