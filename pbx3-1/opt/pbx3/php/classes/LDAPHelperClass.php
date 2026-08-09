<?php
// LDAP Helper class
// Developed by CoCo
//
// Copyright (c) Aelintra Telecom Limited
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

 
Class ldaphelper {
	
	protected $user;
	protected $password;
	protected $ldapserver = '127.0.0.1';
	protected $dbh;
	protected $helper;
	protected $ldapargs; /* used for semi-automatic adds of tenants and security objects */
	
	public $base;
	public $baseou;
	public $addressbook;	
	public $ds;
	
function __construct() {
	$this->helper = new helper; 
	$this->dbh = DB::getInstance();
	$res = $this->dbh->query("SELECT ldapbase, ldapou, ldapuser, ldappass FROM globals LIMIT 1")->fetch(PDO::FETCH_ASSOC);
	if (empty($res)) {
		$res = array('ldapuser' => '', 'ldappass' => '', 'ldapbase' => '', 'ldapou' => '');
	}
	$this->user = 'cn=' . $res['ldapuser'];
	$this->password = $res['ldappass'];
	$this->base = $res['ldapbase'];
	$this->baseou = $res['ldapou'];

	if (empty($this->addressbook)) {
		$this->addressbook = 'ou=' . $res['ldapou'];
	}
}

/**
 * Open LDAP session
 */
public function Connect() {
	$this->ds = ldap_connect($this->ldapserver)
		or die("Could not connect to ldap server: $this->ldapserver");
	ldap_set_option($this->ds, LDAP_OPT_PROTOCOL_VERSION, 3);
	$bind = ldap_bind($this->ds, $this->user . ',' . $this->base, $this->password);
	if (!$bind) {
		return 0;
	} 
	return 1;
}

/**
 * Generalised search
 */
public function Search($filter,$arg) {
	$sr = ldap_search($this->ds, $this->addressbook . "," . $this->base, $filter, $arg);
	return (ldap_get_entries($this->ds, $sr));	
}

/**	
 * Get a single entry using the DN 
 */
public function dnGet($dn) {
	$sr = ldap_search($this->ds, $dn, "cn=*");
	if (empty($sr)) {
		return null;
	}	
	return (ldap_get_entries($this->ds, $sr));	
}

/**	
 * Post a new entry
 */
public function Add($arg) {
	$lkey = "uid=" . uniqid('',true) . ","  . $this->addressbook . "," . $this->base;
	$sr = ldap_add($this->ds, $lkey, $arg);
	if (!$sr) {
		if (ldap_errno($this->ds) == 0x44) { 
         return "Entry already exists!";
		} 
		else { 
			$this->helper->logit("ldap error with key=$lkey, arg=$arg",0);
			return "LDAP ERROR - " . ldap_error($this->ds); 
		}
    } 
    return "Saved new LDAP contact ";	
}

/**	
 * Post a new tenant (OU) object
 */
public function AddNewTenant($tenant) {
	unset ($this->ldapargs);
	$this->ldapargs["objectclass"] = "organizationalUnit";
	$this->ldapargs["ou"] = $tenant;
	
	$lkey = "ou=$tenant,"  . $this->addressbook . "," . $this->base;
/**
 * Check for Duplicate
 */	
	if ($this->dnGet($lkey)) {
		return "Entry already exists!";
	}
/**
 * Add it...
 */

	$sr = ldap_add($this->ds, $lkey, $this->ldapargs);
	if (!$sr) {
		if (ldap_errno($this->ds) == 0x44) { 
		 	$this->helper->logit("ldap key collision with key=$lkey",0);
         	return "Entry already exists!";
		} 
		else { 
			$this->helper->logit("ldap error with key=$lkey",0);
			return "LDAP ERROR - " . ldap_error($this->ds); 
		}
    } 
    return "Saved new LDAP contact ";	
}

/**	
 * Post a new Security object
 */
public function AddNewSimpleSecurityObject($tenant,$pwd) {

	unset ($this->ldapargs);
	$this->ldapargs["objectclass"][0] = "simpleSecurityObject";
	$this->ldapargs["objectclass"][1] = "account";
	$this->ldapargs["userPassword"] = $pwd;
//	$this->ldapargs["cn"] = $tenant;
	$lkey = "uid=$tenant,"  .  $this->base;
/**
 * Check for Duplicate
 */	
if ($this->dnGet($lkey)) {
	return "Entry already exists!";
}

/**
 * Add it...
 */
	$sr = ldap_add($this->ds, $lkey, $this->ldapargs);
	if (!$sr) {
		if (ldap_errno($this->ds) == 0x44) { 
		 	$this->helper->logit("ldap key collision with key=$lkey",0);	
         	return "Entry already exists!";
		} 
		else { 
			$this->helper->logit("ldap error with key=$lkey",0);
			return "LDAP ERROR - " . ldap_error($this->ds); 
		}
    } 
    return "Saved new LDAP contact ";	
}

/**
 * Delete an entry using the DN
 */
public function Delete($dn) {
	$this->helper->logIt("LDAP delete exec with dn = $dn");
	if ( ! ldap_delete($this->ds,$dn)) {
	  $this->helper->logIt("LDAP delete error with dn=$dn");
	  return "LDAP ERROR - " . ldap_error($this->ds);
	}
	return "Deleted $dn OK ";
}

/**
 * Reset - delete all contacts
 * Used by the factory reset function
 */
public function Clean() {
	$arg = array("uid","givenname", "sn", "telephoneNumber", "mobile", "homePhone", "o", "cn");
	$sr=$this->Search("cn=*",$arg);
    for($i=0;$i<$sr['count'];$i++){
		$dn = $sr[$i]['dn'];
        $result = ldap_delete($this->ds,$dn);
        if(!$result){
			//return result code, if delete fails
			return($result);
        }
    }
	return 1;
}

/**
 * DeleteAttribute
 * remove an attribute from an entry
 *
 * @param string $dn
 * @param array $arg
 * @return rc
 */
public function DeleteAttribute ($dn, $arg) {
    if (! ldap_mod_del($this->ds,$dn,$arg)) {
    	$this->helper->logIt("LDAP attribute delete error with dn=$dn");
	  	return "LDAP ERROR - " . ldap_error($this->ds);
    }
    else {
        return "Deleted $dn attribute OK ";
    }
 }

 /**
  * ModifyAttribute
  * modify an attribute in an entry
  *
  * @param string $dn
  * @param array $arg
  * @return rc
  */
 public function ModifyAttribute ($dn, $arg) {
	if (! ldap_mod_replace($this->ds,$dn,$arg)) {  
    	$this->helper->logIt("LDAP attribute modify attribute error with dn=$dn");
	  	return "LDAP ERROR - " . ldap_error($this->ds);
	}
	else { 
		return "Modified $dn attribute OK ";
	} 	
 }

/**
 * End LDAP session
 */
public function Close() {
	ldap_close($this->ds);
	return 1;
}


}