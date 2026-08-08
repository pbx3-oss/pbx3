<?php
// Copyright (c) KoKoSoft 2024-
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

/**
 * fixupTenantLdap
 * read through the tenant (cluster) table and attempt to create an LDAP OU and simplesecurity object for each.
 */

 include(LDAPHELPER);
 include(HELPER);
 include(DBCLASS);

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
