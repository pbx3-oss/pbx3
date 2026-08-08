<?php
// Network Helper class
// Developed by CoCo
//
// Copyright (C) Aelintra Telecom Limited 2018
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

if(php_sapi_name() == 'cli') {
    require_once DBCLASS;
    require_once HELPER;
}
else {
	require_once DBCLASS;
}

Class nethelper {
	
	protected $interfaceName;
	protected $localIPV4;
	protected $dhcpIPV4;
	protected $staticIPV4;
	protected $networkCIDR;
	protected $networkBrd;
	protected $networkIPV4;
	protected $helper;
	protected $dbh;
	


function __construct() {

// interface name
// Find the first active interface and use it

	$firstUpInterface = trim (`ip addr | grep UP | grep -v lo: | head -n1`);
	if (empty($firstUpInterface)) {
		$this->interfaceName = 'ERROR';
	} 
	else {
		preg_match( '/\d:\s*(\w+):?/',$firstUpInterface,$matches);
		$this->interfaceName = trim($matches[1]);
	}

//	staticIPV4
    $this->dbh = DB::getInstance();
	$res = $this->dbh->query("SELECT staticipv4 FROM globals LIMIT 1")->fetch(PDO::FETCH_ASSOC);
	if (isset($res['staticipv4'])) {
		$this->staticIPV4 = $res['staticipv4'];
    }
// localIPV4 & CIDR IPV4
	$iprets = shell_exec( "ip addr show dev " . $this->interfaceName);
	preg_match ( '/inet\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\/\d{1,2}/', $iprets, $matches);
	if (!empty($matches[1])) {
    	$this->localIPV4 = $matches[1];
	}
// dhcpIPV4
	$iprets = shell_exec( "ip -4 addr show dev " . $this->interfaceName . " | grep inet | grep dynamic");
	preg_match ( '/inet\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\/\d{1,2}/', $iprets, $matches);
	if (!empty($matches[1])) {
    	$this->dhcpIPV4 = $matches[1]; 
    }
    else {
    	$this->dhcpIPV4 = $this->localIPV4;
    }   
 // Broadcast IPV4
 	$iprets = shell_exec( "ip -4 addr show dev " . $this->interfaceName . " | grep inet");
 	preg_match ( '/brd\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/', $iprets, $matches); 
	if (!empty($matches[1])) {
		$this->networkBrd = $matches[1];
	}
// network address IPV4
	$iprets = shell_exec( "ip route | grep " . $this->interfaceName );

	preg_match ( '/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\/(\d{1,2})/', $iprets, $matches);
	if (!empty($matches[1])) {	
		$this->networkIPV4 = $matches[1];
	}
// CIDR IPV4

	if (!empty($matches[2])) {	
		$this->networkCIDR = $matches[2];	
	}	
}

/*
 *	functions
 */	

public function get_interfaceName() {
	return $this->interfaceName;
}

public function get_localIPV4() {
	if ($this->staticIPV4) {
		return $this->staticIPV4;
    }
	return $this->localIPV4;
}

public function get_staticIPV4() {
	return $this->staticIPV4;
}

public function set_staticIPV4($oldIp, $newIp) {	
	$this->helper = new helper;	

	if (empty($oldIp) && empty($newIp)) {
		return -1;
	}

	if (!empty($oldIp)) { 	
		$this->helper->request_syscmd ("ip a delete $oldIp/32 dev " . $this->interfaceName);
	}
/* network commands
	$this->helper->request_syscmd ("rm /etc/network/if-up.d" . SYSPREFIX . "_staticipV4");
*/
	if (!empty($newIp)) { 
		sleep(1);
		$this->helper->request_syscmd ("ip a add $newIp dev " .  $this->interfaceName);
/* network commands
		$this->helper->request_syscmd ("echo '#!/bin/bash' > /etc/network/if-up.d" . SYSPREFIX . "_staticipV4");
		$ipcmd = "ip a add $newIp dev " . $this->interfaceName;
		$this->helper->request_syscmd ("echo $ipcmd >> /etc/network/if-up.d" . SYSPREFIX . "_staticipV4");
		$this->helper->request_syscmd ("chmod +x  /etc/network/if-up.d" . SYSPREFIX . "_staticipV4");
*/
	}
	$this->helper->commitOn();
	return;
}

public function get_dhcpIPV4() {
	
	return $this->dhcpIPV4;
}

public function get_networkCIDR() {
	return $this->networkCIDR;
}

public function get_networkBrd() {
	return $this->networkBrd;
}

public function get_networkIPV4() {
	return $this->networkIPV4;
}

public function get_networkGw() {
	$iprets = shell_exec( "ip route | grep default | grep " . $this->interfaceName);
	preg_match ( '/via\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/', $iprets, $matches);
	$networkGw = $matches[1];
	return $networkGw;	
}

public function get_netMask() {
	$work = str_split(str_pad(str_pad('', $this->networkCIDR, '1'), 32, '0'), 8);
    foreach ($work as &$element) $element = bindec($element);
    $netMask = join('.', $work);
	return $netMask;
}

public function get_IPV6LLA() {
	$work = shell_exec( "ip addr show dev " . $this->interfaceName . " | grep 'inet6' | grep fe80 | tr -s ' ' | cut -d ' ' -f 3" ); 
    $work = preg_replace('/\/64$/','',$work); 
    if ($work) {
    	return trim($work);
    }  
	return -1;
}

public function get_IPV6ULA() {
	$work = shell_exec( "ip addr show dev " . $this->interfaceName . " | grep 'inet6' | grep fd84 | tr -s ' ' | cut -d ' ' -f 3" ); 
    $work = preg_replace('/\/64$/','',$work); 
    if ($work) {
    	return trim($work);
    }
	return -1;
}

public function get_IPV6GUA() {
	$work = shell_exec( "ip addr show dev " . $this->interfaceName . " | grep 'inet6' | grep -v fe80 | grep -v fd84 | tr -s ' ' | cut -d ' ' -f 3" );
    $work = preg_replace('/\/64$/','',$work); 
    if ($work) {
    	return trim($work);
    }   
	return -1;
}

public function get_IPV6ALL() {
	$work = shell_exec( "ip addr show dev " . $this->interfaceName . " | grep inet6" );
    if ($work) {
    	$ipv6array = explode(PHP_EOL,$work);
    	foreach($ipv6array as $row) {
    		$row = trim($row);
    	}
    	return array_filter($ipv6array);
    }   
	return -1;
}

public function internetIsUp() {
	exec ("ping -c1 -W2 8.8.8.8",$rets,$retcode);
	switch ($retcode) {
		case 0:				// successful ping
			return True;
		default:
			return False;   // unsuccessful ping
	}
}

public function get_externip() {

	if ($this->internetIsUp()) {
// try DiG first		
		$r1 = trim(`dig +short myip.opendns.com @resolver1.opendns.com`);
		if (filter_var($r1, FILTER_VALIDATE_IP)) {
			return $r1;
		}
//	DiG failed so lets try ipify
		$r2 = `curl --connect-timeout 5  https://api.ipify.org`;
		if (filter_var($r2, FILTER_VALIDATE_IP)) {
			return $r2;
		}
	}
//  No IP so lets bug out	
	return False;   	 		
}

public function restartFirewall() {

	/*  
	 * 	restart the firewall
	 */ 
	
	 	$this->copyFirewallTemplates(); 
		
		$rc = `sudo /sbin/shorewall check 2>&1`;
		if (! strchr($rc, 'ERROR')) {
			$rc = `sudo /sbin/shorewall restart`;
			return(True);
		}
		else {
			return(False);
		}
					
	}
	
	/**
	 * Shorewall INLINE string-match line for SIP FQDN inspect (Option A / LETSENCRYPT_PER_TENANT_FQDN.md).
	 * @param string $proto tcp|udp
	 * @param string $bindport SIP port from globals (e.g. 5060)
	 * @param string $fqdn tenant / node FQDN (Host-Only)
	 */
	private function shorewallFqdnInlineRuleLine($proto, $bindport, $fqdn) {
		// Match sail65 / sark_inline_fqdn: "5060;;" then double-quoted FQDN (no sip: prefix).
		$fqdnEsc = str_replace(['\\', '"'], ['\\\\', '\\"'], $fqdn);
		return 'INLINE(ACCEPT) net $FW ' . $proto . ' ' . $bindport
			. ';; -m string --algo bm --to 1000 --string "' . $fqdnEsc . '"';
	}

	/**
	 * @param string $path absolute path under /etc/shorewall
	 * @param string $content file body (newline-terminated lines)
	 */
	private function writeShorewallFile($path, $content) {
		// Prefer direct write (sudo php / syshelper). Never call syshelper from inside
		// syshelper — the daemon is single-threaded and would deadlock on port 7601.
		if (@file_put_contents($path, $content) !== false) {
			return true;
		}
		if (!isset($this->helper) || !is_object($this->helper)) {
			$this->helper = new helper();
		}
		$tmp = tempnam(sys_get_temp_dir(), 'pbx3fw');
		if ($tmp === false) {
			return false;
		}
		if (@file_put_contents($tmp, $content) === false) {
			@unlink($tmp);
			return false;
		}
		$this->helper->request_syscmd('/bin/mv ' . escapeshellarg($tmp) . ' ' . escapeshellarg($path));
		return true;
	}

	public function copyFirewallTemplates() {

		$this->dbh = DB::getInstance();
		if (!isset($this->helper) || !is_object($this->helper)) {
			$this->helper = new helper();
		}
		$res = $this->dbh->query("SELECT bindport, fqdninspect, sipflood FROM globals LIMIT 1")->fetch(PDO::FETCH_ASSOC);
		if (empty($res)) {
			$res = array('bindport' => '5060', 'fqdninspect' => 'NO', 'sipflood' => 'NO');
		}
		$bindport = (isset($res['bindport']) && $res['bindport'] !== '' && $res['bindport'] !== null)
			? trim($res['bindport']) : '5060';

		$inlineLines = array();
		if (!empty($res['fqdninspect']) && $res['fqdninspect'] === 'YES') {
			$stmt = $this->dbh->query(
				"SELECT fqdn FROM cluster WHERE fqdn IS NOT NULL AND length(trim(fqdn)) > 0 "
				. "ORDER BY CASE WHEN pkey = 'default' THEN 0 ELSE 1 END, pkey"
			);
			$rows = $stmt ? $stmt->fetchAll(PDO::FETCH_ASSOC) : array();
			$seen = array();
			foreach ($rows as $row) {
				$fq = isset($row['fqdn']) ? trim($row['fqdn']) : '';
				if ($fq === '') {
					continue;
				}
				$key = strtolower($fq);
				if (isset($seen[$key])) {
					continue;
				}
				$seen[$key] = true;
				foreach (array('tcp', 'udp') as $proto) {
					$inlineLines[] = $this->shorewallFqdnInlineRuleLine($proto, $bindport, $fq);
				}
			}
		}
		if (empty($inlineLines)) {
			$inlineLines = array('#');
		}
		$this->writeShorewallFile("/etc/shorewall/pbx3_inline_fqdn", implode("\n", $inlineLines) . "\n");

		$file = SYSPATH . '/templates/shorewall/pbx3_inline_limit';
		$limitPath = '/etc/shorewall/pbx3_inline_limit';
		if (file_exists($file) && !empty($res['sipflood']) && $res['sipflood'] == 'YES') {
			if (!@copy($file, $limitPath)) {
				$this->helper->request_syscmd('cp ' . escapeshellarg($file) . ' ' . escapeshellarg($limitPath));
			}
		} else {
			$this->writeShorewallFile($limitPath, "#\n");
		}
	}

}

