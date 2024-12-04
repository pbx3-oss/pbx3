<?php
// +-----------------------------------------------------------------------+
// |  Copyright (c) KoKoSoft 2024-                                  |
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

/**
 * fixupTenantLdap
 * read through the tenant (cluster) table and attempt to create an LDAP OU and simplesecurity object for each.
 */

 include("/opt/sark/php/srkLDAPHelperClass");
 include("/opt/sark/php/srkHelperClass");
 include("/opt/sark/php/srkDbClass");

$helper = new helper;
$ldap = new ldaphelper;

if (!$ldap->Connect()) {
	$helper->logIt("LDAP ERROR 19 - " . ldap_error($ldap->ds));
    exit;
}

$rows = $helper->getTable("cluster");
foreach ($rows as $row ) {
    $ldap->AddNewTenant($row['pkey']);
    $ldap->AddNewSimpleSecurityObject($row['pkey'],$row['ldapropwd']);
}


$ldap->Close();
exit;
