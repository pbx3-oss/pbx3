<?php
// Generator class
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

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
ini_set('error_log', '/var/log/syslog');
error_reporting(E_ALL);

require_once __DIR__ . "/../config.php";

require_once NETHELPER;
//require_once DBCLASS;

/**
 *  Asterisk object generator
 *  It reads the database, generates
 *  the various Asterisk objects and then calls a reload
 */

/**
 * ABOUT KEYS
 * 
 * Almost all rows within the PBX3 database have three keys:-
 * 
 * pkey is only context-wide unique.   It is usually used for diallable numbers which can repeat
 * in other contexts (e.g. two clusters can each have an Ext 301 or a queue 200 etc.)
 * 
 * shortuid is an 8 character ID which will be unique within the PBX3 instance.
 * It is used to uniquely identify objects to Asterisk (endpoints, trunks etc.)
 *  
 * ksuid is a uuid, it is usually the id field within the database row.   
 * It is not generally used within the generator except for database integrity and some DB references when calling the AGI
 * 
 */

/**
 * THE AGI PARAMETER LIST (pbx3cagi.h)
 * After the script path: six comma fields — CMD, KEY, PARM_CLST, PM1, PM2, PM3.
 *
 * PARM_CMD  *(myargv+1) — command name or feature key (*nn*)
 * PARM_KEY  *(myargv+2) — object key (shortuid / pkey) when applicable
 * PARM_CLST *(myargv+3) — cluster shortuid (tenant); required for hub contexts (e.g. inroutes)
 * PARM_PM1–PM3 — Dial / OutQmt / custom use
 *
 * Generator emits CMD, KEY, CLST and leaves PM1–PM3 empty unless needed.
 */

class genAsteriskObjects
{

	private $helper;
	private $nethelper;
	private $dbh;	
	private $globals;
	private $cluster;
	private $appl;
	private $OUT;



	public function genAsterisk()
	{

//		$this->dbh = DB::getInstance();
		$this->helper = new helper;
		$this->nethelper = new nethelper;

		$this->helper->logit(" commit - starting AstGen", 0);
		// Keep generated outputs consistent even if earlier runs used different privileges.
		$this->ensureDirIsWriteable(ASTLOCALCONF);
		$this->ensureDirIsWriteable(DBPATH);

/*** connect to SQLite database ***/
    try {
		$this->dbh = new PDO("sqlite:" . SYSDB);
	}
	catch (Exception $e) {
		$this->helper->logit("Oops failed to open SYSDB", 0);
		exit(4);
	}
		
/**
 * Get the cluster table 
 */
		try {
			$sql = "select * from cluster";
			$res = $this->dbh->query($sql);
			$this->helper->logit("First query", 0);
			$this->cluster = $res->fetchAll();
			$res = NULL;
		} catch (PDOException $e) {
			$errorMsg = $e->getMessage();
			$this->helper->logit(" commit - Fetching clusters failed: " . $errorMsg, 1);
			return $errorMsg;
		}
		$this->helper->logit(" commit - Fetching Globals", 0);

/**
 * Get globals
 */
		try {
			$sql = "select * from globals";
			$res = $this->dbh->query($sql);
			$this->globals = $res->fetch();
			$res = NULL;
		} catch (PDOException $e) {
			$errorMsg = $e->getMessage();
			return $errorMsg;
		}
		$this->helper->logit(" commit - starting procedures", 0);

	
		$this->genMoh();
		$this->genParks();
		$this->genIax();
		$this->genPjsipTransport();
		$this->genPjsipPhones();
		$this->genPjsipWebrtc();
		$this->genPjsipTrunks();
		$this->genQueues();
		$this->genFeatures();
		$this->genVmail();
		$this->genExtensions();
		$this->moveDb();

		$this->dbh = NULL;

		$this->helper->logit(" commit - ending AstGen", 1);
/*
 * take a snapshot
 */
		$rc = $this->helper->request_syscmd("/bin/sh " . SCRIPTS . "/snap.sh");

/*
 * reload asterisk
 */
		$rc = $this->helper->request_syscmd(ASTEXEC . " -rx 'reload'");

		return;
	}

	/**
	 * checkFileIsWriteable
	 * @param  string $fileName
	 * @return bool
	 *
	 *  Checks if a file exists in the Asterisk folder and opens it
	 *  If the file does not exist then create it and write a single comment into it
	 */
	private function checkFileIsWriteable($fileName)
	{

		$q = escapeshellarg($fileName);
		// Generator may be invoked via different privilege paths (e.g. sudo). If outputs were
		// previously created with wrong ownership/mode, repair them before fopen().
		$this->helper->request_syscmd("/bin/touch $q >/dev/null 2>&1");
		$this->helper->request_syscmd("/bin/chown asterisk:asterisk $q >/dev/null 2>&1");
		$this->helper->request_syscmd("/bin/chmod 664 $q >/dev/null 2>&1");

		return True;
	}

	/**
	 * Ensure an output directory is writable by the php/web process via group permissions.
	 * setgid (g+s) keeps newly created files in the `asterisk` group.
	 */
	private function ensureDirIsWriteable($dirPath)
	{
		$q = escapeshellarg($dirPath);
		$this->helper->request_syscmd("/bin/mkdir -p $q >/dev/null 2>&1");
		$this->helper->request_syscmd("/bin/chown asterisk:asterisk $q >/dev/null 2>&1");
		$this->helper->request_syscmd("/bin/chmod 2775 $q >/dev/null 2>&1");
		return True;
	}

/**
 * genMoh
 * generate moh entries for each tenant (cluster)
 * @return void
 */
	private function genMoh()
	{
		$this->OUT = $this->genFileBanner();

		foreach ($this->cluster as $row) {
			if (!file_exists(ASTSHARE . "/moh-" . $row['shortuid'])) {
				$rc = $this->helper->request_syscmd("mkdir " . ASTSHARE . "/moh-" . $row['shortuid']);
			}
			// Class name must match CAGI setMoh: CHANNEL(musicclass)=moh-{cluster shortuid}
			$this->OUT .= "\n; Tenant - " . $row['pkey'] . " (" . $row['shortuid'] . ")\n";
			$this->OUT .= "[moh-" . $row['shortuid'] . "]\n";
			$this->OUT .= "mode=files\n";
			$this->OUT .= "directory=moh-" . $row['shortuid'] . "\n";
			$this->OUT .= "sort=random\n";
		}
		if (!empty($this->OUT)) {
			$this->checkFileIsWriteable(ASTLOCALCONF . "/moh_extra.conf");
			$fh = fopen(ASTLOCALCONF . "/moh_extra.conf", 'w') or die('Could not open file moh_extra.conf!');
			fwrite($fh, $this->OUT) or die('Could not write to file moh_extra.conf');
			fclose($fh);
		}

	}

/**
 * genParks
 * generate a parking lot for each tenant(cluster)
 * @return void
 */
	private function genParks()
	{	
		$readyParks = $this->genFileBanner();
		$parkTimeout = $this->genFileBanner();
		$parkTimeout .= "; Park timeout return-to-parker (comebacktoorigin=no → these contexts)\n";
		$parkTimeout .= "; Fleet Dial must use sip:suid@tenant.fqdn (same as PrepDial); bare PJSIP/suid CHANUNAVAIL.\n";
		$fleet = $this->isFleetMode();
		$Pbuff = NULL;
		foreach ($this->cluster as $row) {
			if (!empty($row['active'])) {
				if ($row['active'] != "YES") {
					continue;
				}
			}
			$suid = (string)($row['shortuid'] ?? '');
			$Pbuff .= $this->helper->getParkInstance(
				$suid,
				isset($row['park_overlay']) ? $row['park_overlay'] : null
			);
			if ($Pbuff) {
				$Pbuff = preg_replace('/\$clstpkey/', (string)($row['pkey'] ?? ''), $Pbuff);
				$Pbuff = preg_replace('/\$clstshortuid/', $suid, $Pbuff);
			}

			$readyParks .= $Pbuff;
			$readyParks .= "\n";
			$Pbuff = NULL;

			if ($suid === '') {
				continue;
			}
			$fqdn = trim((string)($row['fqdn'] ?? ''));
			$parkTimeout .= "\n[park-timeout-" . $suid . "]\n";
			$parkTimeout .= "; Tenant " . (string)($row['pkey'] ?? $suid) . " — EXTEN is flattened PARKER (PJSIP_{shortuid})\n";
			$parkTimeout .= "exten => _PJSIP_.,1,NoOp(Park timeout return \${EXTEN:6} space=\${PARKING_SPACE})\n";
			if ($fleet && $fqdn !== '') {
				$parkTimeout .= " same => n,Dial(PJSIP/\${EXTEN:6}/sip:\${EXTEN:6}@" . $fqdn . ",30,tT)\n";
			} else {
				$parkTimeout .= " same => n,Dial(PJSIP/\${EXTEN:6},30,tT)\n";
			}
			$parkTimeout .= " same => n,Hangup()\n";
		}
/*
 * First, initialise the file with an empty comment
 */
		$targetFile = READY_PARKS;
		$this->checkFileIsWriteable($targetFile);

/*
* Now write the definitions to it (if there are any)
*/
		if ($readyParks) {
			$fh = fopen($targetFile, 'w') or die("Could not open file $targetFile!");
			fwrite($fh, $readyParks) or die("Could not write to file $targetFile !");
			fclose($fh);
		}

		$timeoutFile = READY_PARK_TIMEOUT;
		$this->checkFileIsWriteable($timeoutFile);
		$fh = fopen($timeoutFile, 'w') or die("Could not open file $timeoutFile!");
		fwrite($fh, $parkTimeout) or die("Could not write to file $timeoutFile !");
		fclose($fh);
}
/**
 * genIax
 * generate IAX trunk gateways (if any)
 * @return void
 */
	private function genIax()
	{
		$this->OUT = NULL;

		$trunks = $this->helper->getTable("trunks", null, false);
/**
 *  Bind to the static IP if we are using one
 */
		if (!empty($this->globals['staticipv4'])) {
			$this->OUT = $this->genFileBanner();
			$this->OUT .= 'bindaddr=' . $this->globals['staticipv4'] . "\n"; 
			$this->checkFileIsWriteable(ASTLOCALCONF . "iax_localnet_header.conf");
			$fh = fopen(ASTLOCALCONF . "iax_localnet_header.conf", 'w') or die('Could not open file iax_localnet_header.conf!');
			fwrite($fh,$this->OUT) or die('Could not write to file iax_localnet_header.conf');
			fclose($fh);
		}
/**
 *  Registrations have to be in the [globals] section of iax.conf
 */
		foreach ($trunks as $row) {
			if ($row['register'] != "") {                

				if ($row['technology'] == "IAX2") {
					if ($row['active'] == "YES") {
						$this->OUT .= 'register => ' . $row['register'] . "\n";
					}
				}
			}
		}	
		if (!empty($this->OUT)) {   
			$this->checkFileIsWriteable(ASTLOCALCONF . "iax_registrations.conf");
			$fh = fopen(ASTLOCALCONF . "iax_registrations.conf", 'w') or die('Could not open file iax_registrations.conf!');
			fwrite($fh,$this->OUT) or die('Could not write to file iax_registrations.conf');
			fclose($fh);
		}	
/**
 *  Deal with any IAX trunks
 */	
		$iaxReadyTrunks = $this->genFileBanner();
		$iaxTrunkBuff = NULL;

		foreach ($trunks as $row) {

			if ($row['active'] != "YES") {
				continue;
			}

			if ($row['technology'] == "IAX2"  || $row['technology'] == "Gateway") {
				$iaxTrunkBuff = $this->helper->getIaxInstance($row);
				if ($iaxTrunkBuff) {
					$this->xlatePjsipBuff($iaxTrunkBuff,$row);
				}

				if ($row['privileged'] == "NO") {
					$iaxTrunkBuff = preg_replace('/\$context/', 'Ingress', $iaxTrunkBuff);
				} else {
					$iaxTrunkBuff = preg_replace('/\$context/', (string)($row['cluster'] ?? ''), $iaxTrunkBuff);
				}

				$iaxReadyTrunks .= $iaxTrunkBuff;
				$iaxReadyTrunks .= "\n\n";
				$iaxTrunkBuff = NULL;
			}
		}

/**
 * 
 * write to the ready_trunks file
 * 
 */

/*
 * First, initialise the file with an empty comment
 */
		$targetFile = IAX_READY_TRUNKS;
		$this->checkFileIsWriteable($targetFile);

/*
 * Now write the trunk definitions to it (if there are any)
 */
		if ($iaxReadyTrunks) {
			$fh = fopen($targetFile, 'w') or die("Could not open file $targetFile!");
			fwrite($fh, $iaxReadyTrunks) or die("Could not write to file $targetFile !");
			fclose($fh);
		}
	}

	private function genPjsipTransport()
	{

		$this->OUT = $this->genFileBanner();

		$myExternip = '';
		if (($this->globals['sendedomain'] ?? '') == "YES") {
			if (($this->globals['edomain'] ?? '') != "") {
				$myExternip = $this->globals['edomain'];
			} else {
				$edomaindig = $this->nethelper->get_externip();
				if ($edomaindig) {
					$myExternip = $edomaindig;
				}
			}
		}

		$this->checkFileIsWriteable(PJSIP_TRANSPORT_TEMPLATE);
		$pjsipBuff = file_get_contents(PJSIP_TRANSPORT_TEMPLATE) or die("Could not open " . PJSIP_TRANSPORT_TEMPLATE . " file!\n");
		$pjsipBuff = preg_replace('/\$externip/', $myExternip, $pjsipBuff);

/* 
 * N.B. ToDo - deal with cert/key location here also
 */
		$this->OUT .= $pjsipBuff;
		$this->OUT .= "\n";

		$this->checkFileIsWriteable(PJSIP_TRANSPORT);
		$fh = fopen(PJSIP_TRANSPORT, 'w') or die("Could not open " . PJSIP_TRANSPORT . "!\n");
		fwrite($fh, $this->OUT) or die("Could not write to file " . PJSIP_TRANSPORT);
		fclose($fh);

		$this->OUT = NULL;
	}


/**
 * genPjsipPhones
 * genarate sip entries for each phone (if any)
 * @return void
 */
	private function genPjsipPhones()
	{

		$this->OUT = NULL;
		$pjsipPhoneBuff = NULL;
		$phones = $this->helper->getTable("ipphone", null, false);

		foreach ($phones as $row) {

			if ($row['active'] != "YES") {
				continue;
			}

			if ($row['device'] == "WebRTC") {
				continue;
			}

			$pjsipPhoneBuff .= "\n; Tenant - " . $row['cluster'] . "\n";
			$pjsipPhoneBuff .= "; Phone - " . $row['shortuid'] . " (" . $row['pkey'] . ")\n";
			$dbOverlay = isset($row['pjsip_overlay']) ? $row['pjsip_overlay'] : null;
			$pjsipPhoneBuff .= $this->helper->getPjsipPhoneInstance($row['shortuid'], $dbOverlay);

			if ($pjsipPhoneBuff) {
				$this->xlatePjsipBuff($pjsipPhoneBuff, $row);
			}

			$this->OUT .= $pjsipPhoneBuff;
			$pjsipPhoneBuff = NULL;
		}

		$targetFile = PJSIP_READY_PHONES;
		$this->checkFileIsWriteable($targetFile);

/*
 *	If $this->OUT is empty, put a single comment in it
 */
		if (empty($this->OUT)) {
			$this->OUT = ";";
		}

	$fh = fopen($targetFile, 'w') or die('Could not open file pjsip_ready_phones.conf!');
	fwrite($fh,$this->OUT) or die('Could not write to file pjsip_ready_phones.conf');
	fclose($fh);


		$this->OUT = NULL;
	}

/**
 * genPjsipWebrtc
 * generate webRTC entries for each webphone (if any)
 * @return void
 */
	private function genPjsipWebrtc()
	{

		$this->OUT = NULL;
		$pjsipPhoneBuff = NULL;
		$phones = $this->helper->getTable("ipphone", null, false);

		// WSS outbound INVITE Contact/SDP: public FQDN + public IP (see pjsip_webrtc.tmpl $fqdn / $externip).
		$myExternip = '';
		if (($this->globals['sendedomain'] ?? '') == "YES") {
			if (($this->globals['edomain'] ?? '') != "") {
				$myExternip = $this->globals['edomain'];
			} else {
				$edomaindig = $this->nethelper->get_externip();
				if ($edomaindig) {
					$myExternip = $edomaindig;
				}
			}
		}
		// Prefer dig IP for media_address when edomain is a hostname (Contact uses $fqdn).
		if ($myExternip !== '' && !filter_var($myExternip, FILTER_VALIDATE_IP)) {
			$digIp = $this->nethelper->get_externip();
			if ($digIp) {
				$myExternip = $digIp;
			}
		}
		$myFqdn = '';
		$leDomainFile = '/opt/pbx3/etc/identity/le-domain';
		if (is_readable($leDomainFile)) {
			$myFqdn = trim((string) @file_get_contents($leDomainFile));
		}
		if ($myFqdn === '' && ($this->globals['edomain'] ?? '') != ''
			&& !filter_var($this->globals['edomain'], FILTER_VALIDATE_IP)) {
			$myFqdn = (string) $this->globals['edomain'];
		}

		foreach ($phones as $row) {

			if ($row['active'] != "YES") {
				continue;
			}

			if ($row['device'] != "WebRTC") {
				continue;
			}

			$pjsipPhoneBuff = $this->helper->getPjsipWebrtcInstance(
				$row['shortuid'],
				isset($row['pjsip_overlay']) ? $row['pjsip_overlay'] : null
			);

			if ($pjsipPhoneBuff) {
				$this->xlatePjsipBuff($pjsipPhoneBuff, $row);
				$pjsipPhoneBuff = preg_replace('/\$externip/', $myExternip, $pjsipPhoneBuff);
				$pjsipPhoneBuff = preg_replace('/\$fqdn/', $myFqdn, $pjsipPhoneBuff);
			}

			$this->OUT .= $pjsipPhoneBuff . "\n\n";
			$pjsipPhoneBuff = NULL;
		}

		$targetFile = PJSIP_READY_WEBRTC;
		$this->checkFileIsWriteable($targetFile);

/*
 *	If $this->OUT is empty, put a single comment in it
 */
		if (empty($this->OUT)) {
			$this->OUT = ";";
		}

	$fh = fopen($targetFile, 'w') or die('Could not open file pjsip_ready_webrtc.conf!');
	fwrite($fh,$this->OUT) or die('Could not write to file pjsip_ready_webrtc.conf');
	fclose($fh);

		$this->OUT = NULL;
	}


/**
 * genPjsipTrunks
 * generate peer entries for the upstream and downstream (if any)) 
 * @return void
 */
	private function genPjsipTrunks()
	{

		$trunks = $this->helper->getTable("trunks", null, false);

		$pjsipReadyTrunks = $this->genFileBanner();
		$pjsipTrunkBuff = NULL;

		foreach ($trunks as $row) {

			if ($row['technology'] != "SIP") {
				continue;
			}

			if ($row['active'] != "YES") {
				continue;
			}

			$pjsipTrunkBuff = $this->helper->getPjsipTrunkInstance(
				$row,
				isset($row['pjsip_overlay']) ? $row['pjsip_overlay'] : null
			);
			if ($pjsipTrunkBuff) {
				$this->xlatePjsipBuff($pjsipTrunkBuff,$row);
			}
		

			/*
			 * Fleet Egress: Prefer SbcDomainRoute so sip:{ext}@{tenant.fqdn}
			 * from Magrathea (PrefixDial miss→home) lands in tenant dialplan.
			 * Carrier DID RURIs (domain ≠ tenant FQDN, or +E164) fall through
			 * to Ingress. Privileged trunks still use cluster context.
			 */
			if (($row['pkey'] ?? '') === 'Egress' && $this->isFleetMode()) {
				$pjsipTrunkBuff = preg_replace('/\$context/', 'SbcDomainRoute', $pjsipTrunkBuff);
			} elseif ($row['privileged'] == "NO") {
				$pjsipTrunkBuff = preg_replace('/\$context/', 'Ingress', $pjsipTrunkBuff);
			} else {
				$pjsipTrunkBuff = preg_replace('/\$context/', (string)($row['cluster'] ?? ''), $pjsipTrunkBuff);
			}
			$pjsipReadyTrunks .= $pjsipTrunkBuff;
			$pjsipReadyTrunks .= "\n\n";
			$pjsipTrunkBuff = NULL;
		}

		/*
		 * Fleet: one outbound PJSIP face per tenant for PrefixDial.
		 * from_domain = tenant FQDN so CALLERID(num)=shortuid becomes From
		 * sip:suid@tenant.fqdn (not suid%40fqdn@host). Same SBC contact as Egress.
		 * Outbound only — no identify (shared SBC IP stays on Egress identify).
		 */
		if ($this->isFleetMode()) {
			$sbcHost = $this->fleetSbcHost();
			try {
				$sql = "SELECT shortuid, fqdn FROM cluster WHERE fqdn IS NOT NULL AND TRIM(fqdn) != '' ORDER BY shortuid";
				$qRes = $this->dbh->query($sql);
				$tenants = $qRes ? $qRes->fetchAll() : [];
				$qRes = NULL;
				$instanceFqdn = '';
				$gq = $this->dbh->query("SELECT fqdn FROM globals LIMIT 1");
				$grow = $gq ? $gq->fetch(PDO::FETCH_ASSOC) : false;
				if ($grow && !empty($grow['fqdn'])) {
					$instanceFqdn = strtolower(trim((string) $grow['fqdn']));
				}
				foreach ($tenants as $trow) {
					$suid = isset($trow['shortuid']) ? trim((string) $trow['shortuid']) : '';
					$fqdn = isset($trow['fqdn']) ? strtolower(trim((string) $trow['fqdn'])) : '';
					if ($suid === '' || !preg_match('/^[a-z0-9]+$/i', $suid)) {
						continue;
					}
					if ($fqdn === '' || !preg_match('/^[a-z0-9][a-z0-9.-]+\.[a-z]{2,}$/i', $fqdn)) {
						continue;
					}
					// Never use instance FQDN as a SIP From domain (not a tenant namespace)
					if ($instanceFqdn !== '' && $fqdn === $instanceFqdn) {
						continue;
					}
					$ep = 'SbcSiteOut' . $suid;
					$pjsipReadyTrunks .= "; Tenant site-dial outbound ({$suid} → From domain {$fqdn})\n";
					$pjsipReadyTrunks .= "[{$ep}]\n";
					$pjsipReadyTrunks .= "type=endpoint\n";
					$pjsipReadyTrunks .= "transport=transport-udp\n";
					$pjsipReadyTrunks .= "context=SbcDomainRoute\n";
					$pjsipReadyTrunks .= "rtp_symmetric=yes\n";
					$pjsipReadyTrunks .= "force_rport=yes\n";
					$pjsipReadyTrunks .= "rewrite_contact=yes\n";
					$pjsipReadyTrunks .= "disallow=all\n";
					$pjsipReadyTrunks .= "allow=ulaw\n";
					$pjsipReadyTrunks .= "allow=alaw\n";
					$pjsipReadyTrunks .= "aors={$ep}\n";
					$pjsipReadyTrunks .= "direct_media=no\n";
					$pjsipReadyTrunks .= "from_domain={$fqdn}\n";
					/* trust PAI if hairpin path ever hits this face inbound (rare) */
					$pjsipReadyTrunks .= "trust_id_inbound=yes\n";
					$pjsipReadyTrunks .= "outbound_proxy=sip:{$sbcHost}\\;lr\n";
					$pjsipReadyTrunks .= "\n";
					$pjsipReadyTrunks .= "[{$ep}]\n";
					$pjsipReadyTrunks .= "type=aor\n";
					$pjsipReadyTrunks .= "contact=sip:{$sbcHost}\n";
					$pjsipReadyTrunks .= "qualify_frequency=30\n";
					$pjsipReadyTrunks .= "\n\n";
				}
				/*
				 * Outbound face for ringing a handset after site-dial receive.
				 * send_pai=no so PJSIP does not overwrite PrepDial b() PAI
				 * (return AoR) with CALLERID presentation digits.
				 */
				$pjsipReadyTrunks .= "; Fleet site-dial ring: PAI via dialplan only\n";
				$pjsipReadyTrunks .= "[SiteRing]\n";
				$pjsipReadyTrunks .= "type=endpoint\n";
				$pjsipReadyTrunks .= "transport=transport-udp\n";
				$pjsipReadyTrunks .= "context=SbcDomainRoute\n";
				$pjsipReadyTrunks .= "rtp_symmetric=yes\n";
				$pjsipReadyTrunks .= "force_rport=yes\n";
				$pjsipReadyTrunks .= "rewrite_contact=yes\n";
				$pjsipReadyTrunks .= "disallow=all\n";
				$pjsipReadyTrunks .= "allow=ulaw\n";
				$pjsipReadyTrunks .= "allow=alaw\n";
				$pjsipReadyTrunks .= "aors=SiteRing\n";
				$pjsipReadyTrunks .= "direct_media=no\n";
				$pjsipReadyTrunks .= "send_pai=no\n";
				$pjsipReadyTrunks .= "outbound_proxy=sip:{$sbcHost}\\;lr\n";
				$pjsipReadyTrunks .= "\n";
				$pjsipReadyTrunks .= "[SiteRing]\n";
				$pjsipReadyTrunks .= "type=aor\n";
				$pjsipReadyTrunks .= "contact=sip:{$sbcHost}\n";
				$pjsipReadyTrunks .= "qualify_frequency=30\n";
				$pjsipReadyTrunks .= "\n\n";
			} catch (PDOException $e) {
				// leave trunks as Egress-only
			}
		}

/**
 * 
 * write to the ready_trunks file
 * 
 */

/*
 * First, initialise the file with an empty comment
 */
		$targetFile = PJSIP_READY_TRUNKS;
		$this->checkFileIsWriteable($targetFile);

		if (empty($pjsipReadyTrunks)) {
			$pjsipReadyTrunks = ";";
		}

		$fh = fopen($targetFile, 'w') or die("Could not open file $targetFile!");
		fwrite($fh, $pjsipReadyTrunks) or die("Could not write to file $targetFile !");
		fclose($fh);
	}

/**
 * xlatePjsipBuff  - substitute the symbolic values in the template buffer with real 
 * ones from the tuple
 * @param  string &$buffer The template to be transformed
 * @param  Array $row     The DB tuple for the object
 * @return Bool   
 */
	/**
	 * Fleet edge present (same idea as pbx3cagi pbx3_fleet_mode):
	 * PBX3_FLEET_MODE env, else active trunks.pkey=Egress.
	 * Gates tenant-AoR dials + phone outbound_proxy (singleton talks to phones directly).
	 */
	private function isFleetMode(): bool
	{
		$env = getenv('PBX3_FLEET_MODE');
		if ($env !== false && $env !== '') {
			$v = strtolower(trim($env));
			if (in_array($v, ['1', 'true', 'yes'], true)) {
				return true;
			}
			if (in_array($v, ['0', 'false', 'no'], true)) {
				return false;
			}
		}
		try {
			$q = $this->dbh->query("SELECT active FROM trunks WHERE pkey='Egress' LIMIT 1");
			$row = $q ? $q->fetch(PDO::FETCH_ASSOC) : false;
			return $row && (($row['active'] ?? '') === 'YES');
		} catch (PDOException $e) {
			return false;
		}
	}

	/**
	 * Destination tenant ext_len for PrefixDial pattern (local cluster only; else $fallback).
	 */
	private function resolveDialTargetExtLen(array $aliasrow, int $fallback): int
	{
		$fallback = ($fallback >= 2 && $fallback <= 5) ? $fallback : 3;
		$pin = isset($aliasrow['target_cluster']) ? trim((string) $aliasrow['target_cluster']) : '';
		if ($pin !== '') {
			try {
				$st = $this->dbh->prepare('SELECT ext_len FROM cluster WHERE shortuid = ? OR pkey = ? OR id = ? LIMIT 1');
				$st->execute([$pin, $pin, $pin]);
				$r = $st->fetch(PDO::FETCH_ASSOC);
				if ($r && isset($r['ext_len']) && is_numeric($r['ext_len'])) {
					$n = (int) $r['ext_len'];
					if ($n >= 3 && $n <= 5) {
						return $n;
					}
				}
			} catch (PDOException $e) {
				// fall through
			}
		}
		$fqdn = isset($aliasrow['target_fqdn']) ? strtolower(trim((string) $aliasrow['target_fqdn'])) : '';
		if ($fqdn !== '') {
			try {
				$st = $this->dbh->prepare('SELECT ext_len FROM cluster WHERE lower(trim(fqdn)) = ? LIMIT 1');
				$st->execute([$fqdn]);
				$r = $st->fetch(PDO::FETCH_ASSOC);
				if ($r && isset($r['ext_len']) && is_numeric($r['ext_len'])) {
					$n = (int) $r['ext_len'];
					if ($n >= 3 && $n <= 5) {
						return $n;
					}
				}
			} catch (PDOException $e) {
				// fall through
			}
		}
		return $fallback;
	}

	/**
	 * Active extension pkeys for a tenant (queue.cluster is usually shortuid).
	 * Used by genQueues to tell desk members (Local/Q…) from PSTN (Local/{n}@tenant).
	 *
	 * @return array<string, true> pkey => true
	 */
	private function extensionPkeysForCluster($cluster)
	{
		static $cache = null;
		if ($cache === null) {
			$cache = [];
			try {
				$phones = $this->helper->getTable('ipphone', null, false);
			} catch (Exception $e) {
				$phones = [];
			}
			if (!is_array($phones)) {
				$phones = [];
			}
			foreach ($phones as $p) {
				if (($p['active'] ?? 'YES') === 'NO') {
					continue;
				}
				$cl = isset($p['cluster']) ? trim((string) $p['cluster']) : '';
				$pkey = isset($p['pkey']) ? trim((string) $p['pkey']) : '';
				if ($cl === '' || $pkey === '') {
					continue;
				}
				if (!isset($cache[$cl])) {
					$cache[$cl] = [];
				}
				$cache[$cl][$pkey] = true;
			}
		}
		$cluster = trim((string) $cluster);
		if ($cluster === '' || !isset($cache[$cluster])) {
			return [];
		}
		return $cache[$cluster];
	}

	/**
	 * Stable SBC SIP host for phone outbound_proxy (Phase F).
	 * Same env as fleet egress seed (PBX3_SBC_EGRESS_HOST); default lab/prod VIP name.
	 */
	private function fleetSbcHost(): string
	{
		$h = getenv('PBX3_SBC_EGRESS_HOST');
		if ($h !== false && trim($h) !== '') {
			return trim($h);
		}
		try {
			$q = $this->dbh->query("SELECT host FROM trunks WHERE pkey='Egress' AND active='YES' LIMIT 1");
			$row = $q ? $q->fetch(PDO::FETCH_ASSOC) : false;
			$host = trim((string) ($row['host'] ?? ''));
			if ($host !== '') {
				return $host;
			}
		} catch (PDOException $e) {
			// fall through to historic default
		}
		return 'sbc.pbx3.com';
	}

	/**
	 * Expand template tokens in a PJSIP/queue buffer before write.
	 * Token notes:
	 *   $id / $pkey / $ext / $username — object identity (phones: shortuid vs dialable pkey)
	 *   $clst — tenant shortuid (COS / mailbox domain)
	 *   $clstkey — parking lot name park-{tenant shortuid} (must run before $clst)
	 *   $named_call_group / $named_pickup_group — PJSIP named groups (ALL/empty → $clst)
	 *   $outbound_proxy — whole line or empty (fleet → sip:{PBX3_SBC_EGRESS_HOST};lr)
	 */
	private function xlatePjsipBuff(&$buffer, $row)
	{
		$rep = function ($v) { return (string)($v ?? ''); };
		$outbound = $this->isFleetMode()
			? 'outbound_proxy=sip:' . $this->fleetSbcHost() . "\\;lr\n"
			: '';
		// Line-anchored: do not substitute the token inside comments (e.g. "; $outbound_proxy …").
		$buffer = preg_replace('/^\$outbound_proxy\n?/m', $outbound, $buffer);

		$buffer = preg_replace('/\$id/', $rep($row['shortuid'] ?? null), $buffer);
		$buffer = preg_replace('/\$pkey/', $rep($row['pkey'] ?? null), $buffer);
		$buffer = preg_replace('/\$trunk/', $rep($row['pkey'] ?? null), $buffer);
		// $ext must not eat $externip (pkey 999 → media_address=999ernip).
		$buffer = preg_replace('/\$ext(?![A-Za-z0-9_])/', $rep($row['pkey'] ?? null), $buffer);
		$buffer = preg_replace('/\$username/', $rep($row['pkey'] ?? null), $buffer);

		// parkinglot=park-{tenant} — replace $clstkey before $clst (else $clst eats the prefix)
		$clst = $rep($row['cluster'] ?? null);
		$clstkey = ($clst !== '') ? ('park-' . $clst) : '';
		$buffer = preg_replace('/\$clstkey/', $clstkey, $buffer);
		// Named call/pickup: ALL or empty → tenant shortuid (tenant-scoped whole-tenant pool).
		// Custom tokens (sales, 1,2, …) emit as-is. Replace before $clst.
		$resolveNamed = function ($raw) use ($clst, $rep) {
			$v = trim($rep($raw));
			if ($v === '' || strcasecmp($v, 'ALL') === 0) {
				return $clst;
			}
			return $v;
		};
		$buffer = preg_replace('/\$named_call_group/', $resolveNamed($row['named_call_group'] ?? null), $buffer);
		$buffer = preg_replace('/\$named_pickup_group/', $resolveNamed($row['named_pickup_group'] ?? null), $buffer);
		// Legacy single-field templates (pre-split): both sides from named_groups if still present.
		if (strpos($buffer, '$named_groups') !== false) {
			$legacy = $resolveNamed($row['named_groups'] ?? ($row['named_call_group'] ?? null));
			$buffer = preg_replace('/\$named_groups/', $legacy, $buffer);
		}
		$buffer = preg_replace('/\$clst/', $clst, $buffer);

		if (!empty($row['strategy'])) {
			$buffer = preg_replace('/\$strategy/', $rep($row['strategy'] ?? null), $buffer);
		}
		// queue.tmpl timing — SPA Timing & limits; defaults match former hardcodes
		$qTimeout = (isset($row['timeout']) && $row['timeout'] !== '' && $row['timeout'] !== null)
			? (string) (int) $row['timeout'] : '30';
		$qRetry = (isset($row['retry']) && $row['retry'] !== '' && $row['retry'] !== null)
			? (string) (int) $row['retry'] : '1';
		$qWrap = (isset($row['wrapuptime']) && $row['wrapuptime'] !== '' && $row['wrapuptime'] !== null)
			? (string) (int) $row['wrapuptime'] : '0';
		$qMaxlen = (isset($row['maxlen']) && $row['maxlen'] !== '' && $row['maxlen'] !== null)
			? (string) (int) $row['maxlen'] : '0';
		$buffer = preg_replace('/\$timeout/', $qTimeout, $buffer);
		$buffer = preg_replace('/\$retry/', $qRetry, $buffer);
		$buffer = preg_replace('/\$wrapuptime/', $qWrap, $buffer);
		$buffer = preg_replace('/\$maxlen/', $qMaxlen, $buffer);
/**
 * default to udp for converted rows from imported systems
 */
		if (empty($row['transport'])) {
			$row['transport'] = 'udp';
		}
		$buffer = preg_replace('/\$transport/', $rep($row['transport'] ?? null), $buffer);

		if (!empty($row['description'])) {
			$buffer = preg_replace('/\$desc/', $rep($row['description'] ?? null), $buffer);
		}
		else {
			$buffer = preg_replace('/\$desc/', $rep($row['pkey'] ?? null), $buffer);
		}
		if (!empty($row['host'])) {
			$buffer = preg_replace('/\$host/', $rep($row['host'] ?? null), $buffer);
		}
/*
 * Accident of history; trunks and phones do not use the same column name
 * for password (password and passwd)
 */
		if (!empty($row['password'])) {
			$buffer = preg_replace('/\$password/', $rep($row['password'] ?? null), $buffer);
		} else if (!empty($row['passwd'])) {
			$buffer = preg_replace('/\$password/', $rep($row['passwd'] ?? null), $buffer);
		}
		return True;
	}
/**
 * genQueues
 *
 * @return void
 */
	private function genQueues()
	{
		
		$result = $this->helper->getTable("queue", null, false);

		$readyQueues = $this->genFileBanner();
		$Qbuff = NULL;
		foreach ($result as $row) {
			if (!empty($row['active'])) {
				if ($row['active'] != "YES") {
					continue;
				}
			}
/**
 *  ignore page groups - they are handled elsewhere
 */
			if ($row['strategy'] == "page") {
				continue;
			}	
 
			$Qbuff .= "\n; Tenant - " . $row['cluster'] . "\n";
			$Qbuff .= "; Queue - " . $row['name'] . "\n";
			$Qbuff .= "; Members - " . $row['members'] . "\n";
			$Qbuff .= "; Desc - " . $row['description'] . "\n";
			$Qbuff .= "; DirectDial - " . $row['pkey'] . "\n\n";

			$Qbuff .= "[" . $row['shortuid'] . "]\n";


			$Qbuff .= $this->helper->getQInstance(
				$row['pkey'],
				isset($row['queue_overlay']) ? $row['queue_overlay'] : null
			);
			if ($Qbuff) {
				$this->xlatePjsipBuff($Qbuff,$row);
			}
			if (!empty($row['members'])) {
				$row['members'] = preg_replace('/\s+/', " ", $row['members']);
				$row['members'] = preg_replace('/\s*$/', "", $row['members']);
				$Qbuff .= "\n";
				$extension = explode(" ", $row['members']);
				$cluster = $row['cluster'];
				$localExts = $this->extensionPkeysForCluster($cluster);
				foreach ($extension as $ext) {
					$ext = trim((string) $ext);
					if ($ext === '') {
						continue;
					}
					// Tenant extension → Local/Q{ext} (PrepDial queue path).
					// Non-extension (PSTN etc.) → Local/{num}@{tenant} so OutRoute matches
					// (SARK Alias used Local/{n}@internal for the same idea).
					if (isset($localExts[$ext])) {
						$Qbuff .= "member=Local/Q" . $ext . "@" . $cluster . "\n";
					} else {
						$Qbuff .= "member=Local/" . $ext . "@" . $cluster . "\n";
					}
				}
			}
			$readyQueues .= $Qbuff;
			$readyQueues .= "\n";
			$Qbuff = NULL;
		}
/*
 * First, initialise the file with an empty comment
 */
		$targetFile = READY_QUEUES;
		$this->checkFileIsWriteable($targetFile);

/*
* Now write the queue definitions to it (if there are any)
*/
		if ($readyQueues) {
			$fh = fopen($targetFile, 'w') or die("Could not open file $targetFile!");
			fwrite($fh, $readyQueues) or die("Could not write to file $targetFile !");
			fclose($fh);
		}
}

/**
 * genfeatures
 * Not sure ths is necessary - does nothing for now
 * @return void
 */
	private function genFeatures()
	{
/*

		$this->OUT = $this->genFileBanner();

		$this->OUT .= "#include features_general.conf  \n";
		$this->OUT .= "#include features_featuremap.conf  \n";
		$this->OUT .= "#include features_applicationmap.conf  \n";

		$fh = fopen(ASTLOCALCONF . "/features.conf", 'w') or die('Could not open file features.conf!');
		fwrite($fh, $this->OUT . " \n")
			or die('Could not write to file features.conf ');
		fclose($fh);
*/
	}


	private function genVmail()
	{

		$mailbox = array();
		$parts = array();
		$context = '[null]';

		// read the existing file to preserve passwords and options

		$file = ASTLOCALCONF . '/voicemail.conf';
		if (file_exists($file)) {
			$rec = file($file) or die("Could not read file $file !");
			foreach ($rec as $line) {
				$line = trim($line);
/*
 * Context not currently used but may be in future
 */
				if (preg_match(" /^(\[.*\])$/ ", $line, $matches)) {
					$context = $matches[1];
				}

				if (!preg_match(" /^;.*/", $line)) {
					$line = preg_replace('/\s+/', ' ', $line);
					if (preg_match(" /^(\d{3,6})\s*=>\s*((\d*)?),/", $line, $matches)) {
						$mailbox[$context][$matches[1]]['password'] = substr($matches[2], 2);
					}
					$parts = explode('=>', $line);
					if (isset($parts[1])) {
						$exten = trim($parts[0]);
						$params = explode(',', $parts[1]);
						if (isset($params[1])) {
							$mailbox[$context][$exten]['name'] = trim($params[1]);
						}
						if (isset($params[2])) {
							$mailbox[$context][$exten]['email'] = trim($params[2]);
						}
						if (isset($params[3])) {
							$mailbox[$context][$exten]['options'] = trim($params[3]);
						}
						if (isset($params[4])) {
							$mailbox[$context][$exten]['options'] .= ',' . trim($params[4]);
						}
					}
				}
			}
		}

		$this->OUT = <<<BANNEREND
;
;               Modifying this file
; This file is generated by the pbx3 Asterisk generator code and
; it will be overwritten each time you issue a COMMIT.  
; However, it will preserve changes to the voicemail
; passwords provided you use passwords of either three or four digits.  
; You may also supply an options statement at the end of each mailbox stanza.
;
#include vmail_header.conf
#tryinclude customer_vmail_header.conf
#include vmail_layout.conf

[default]

BANNEREND;

		$result = $this->helper->getTable("ipphone", null, false, false, "cluster,pkey");
		$clusterChange = null;
		foreach ($result as $row) {
			if ($row['cluster'] != $clusterChange) {
				$clusterChange = $row['cluster'];
				$this->OUT .= "[" . $clusterChange . "]\n";
			}
			if ($row['dvrvmail'] != 'None') {
				if (!empty($mailbox[$row['cluster']][$row['pkey']]['password'])) {
					$pwd = $mailbox[$row['cluster']][$row['pkey']]['password'];
				} else {
					$pwd = ($row['pkey']);
				}
				$this->OUT .= $row['pkey'] . ' => ' . $pwd . ',' . $row['description'] . ',' .
					$row['vmailfwd'];
				if (isset($mailbox[$row['cluster']][$row['pkey']]['options'])) {
					$this->OUT .= ',' . $mailbox[$row['cluster']][$row['pkey']]['options'];
				}
				$this->OUT .= " \n";
			}
		}

		$this->checkFileIsWriteable(ASTLOCALCONF . "/voicemail.conf");
		$fh = fopen(ASTLOCALCONF . "/voicemail.conf", 'w') or die('Could not open file voicemail.conf!');
		fwrite($fh, $this->OUT) or die('Could not write to file voicemail.conf');
		fclose($fh);
	}

	private function moveDb()
	{
		$sourcedb = SYSDB;
		$transitdb = DBPATH . "/system.copy.db";
		$rdonlydb = READONLY_DB;

		shell_exec("/bin/cp $sourcedb $transitdb");
		shell_exec("/bin/mv $transitdb $rdonlydb");
	}

	private function genFileBanner()
	{

		$this->OUT = <<<BANNEREND
;
;               DO NOT MODIFY THIS FILE
; It is generated by the Asterisk generator code and
; it will be overwritten each time you issue a COMMIT to the node
;

BANNEREND;

		return $this->OUT;
	}
/**
 * Undocumented function
 *
 * @return void
 */
    private function genExtensions()
    {

        $this->OUT = $this->genFileBanner();

        $release = shell_exec(ASTEXEC . " -rx 'core show version'");
        $vers = '1.8';
        if (preg_match(' /Asterisk\s*(\d\d).*$/ ', $release, $matches)) {
            $vers = $matches[1];
        }
        echo 'Asterisk version is ' . $vers . "\n";

        $this->genExtensionsGlobals();
		$this->genExtensionsFeatures();
		$this->genExtensionsCoS();
        $this->genExtensionsEndpoints();		
        $this->genExtensionsCosTests();		
        $this->genExtensionsFromPeers();		
        $this->genExtensionsCustomApps();

	if (!$this->OUT) {
		die('OUT is empty!');
	}
        // write the generated file 
        $myExtensions = ASTLOCALCONF . "/extensions.conf";
        $this->checkFileIsWriteable($myExtensions);
        $fh = fopen($myExtensions, 'w') or die('Could not open file extensions.conf!');
        fwrite($fh, $this->OUT) or die('Could not write to file extensions.conf');
        fclose($fh);

        // clean it
        system ("dos2unix $myExtensions >/dev/null 2>&1");
        //
        //	All done.	
        //

    }


//		try {
/**
 * Undocumented function
 *
 * @return void
 */
    private function genExtensionsGlobals()
    {
        $this->OUT .= "[general] \n";
            $this->OUT .= "static=yes \n";
            $this->OUT .= "writeprotect=yes \n";
            $this->OUT .= "[globals] \n";
        //
        //	output our main reference globals	
        //

        $displayglobals = array(
            "abstimeout", "emergency", "language", "operator", "sysop", "syspass", "voipmax", "maxin"
        );

        $this->globals['language'] = ASTLANG;
    /**
     * Placeholder to remember to fix operator
     *
     *			if (empty($this->globals['operator'])) {
     *				$this->globals['operator'] = "100";
     *			}
     */
        $em = (string) ($this->globals['emergency'] ?? '');
        $this->globals['emergency'] = preg_replace('/\s*$/', "", preg_replace('/\s+/', " ", $em));

        foreach ($displayglobals as $name) {
            $this->OUT .= "\t" . strtoupper($name) . "=" . ($this->globals[$name] ?? '') . "\n";
        }

        $this->OUT .= "\tSET_DYNAMIC_FEATURES=>YES\n";
        $this->OUT .= "\tSYSAGI=" . SYSAGI . "\n";

        $this->OUT .= "\n";
        //
        //  include any customer supplied globals
        //
        if (file_exists(ASTLOCALCONF . "/customer_extensions_globals.conf")) {
            $this->OUT .= ";\tCustomer supplied Globals (include file)\n";
            $this->OUT .= ";\n";
            $this->OUT .= "#include customer_extensions_globals.conf \n";
            $this->OUT .= ";\n";
        }
    }


private function genExtensionsCoS()
{
//
//  CoS (clusters)
//

    foreach ($this->cluster as $row) {
        $myCluster = $row['pkey'];
        $myClusterId = $row['shortuid'];
/*		
        if ($row['pkey'] == "default") {
            $myCluster = 'qrxvtmny';
            $myClusterId = 'qrxvtmny';
        }
*/        
        $this->OUT .= "\n; Tenant - " . $row['pkey'] . "\n";
        $this->OUT .= "; Class of Service (CoS)\n";
        $this->OUT .= "[COS_$myClusterId]\n";
        $this->OUT .= "\texten => _*X.,1,GoTo($myClusterId,\${EXTEN},1)\n";
        $dialplan = explode(" ", (string) ($this->globals['emergency'] ?? ''));
        foreach ($dialplan as $plan) {
            $this->OUT .= "\texten => $plan,1,GoTo($myClusterId,\${EXTEN},1)\n";;
        }

        // Park retrieve slots (exact) — must beat COS `_X.` or dial-901 never reaches park-* include.
        // Stock lot parkpos 901-903; overlay may widen later (keep in sync with parking_lot.tmpl).
        for ($parkPos = 901; $parkPos <= 903; $parkPos++) {
            $this->OUT .= "\texten => $parkPos,1,GoTo($myClusterId,\${EXTEN},1)\n";
        }

        $this->OUT .= "\texten => _X.,1,GoToIf(\$[\${LEN(\${CALLERID(num)})} > 6]?$myClusterId,\${EXTEN},1)\n";
        $this->OUT .= "\texten => _X.,2,SET(myClusterOclo=\${DB($myClusterId/STATE)})\n";

        $this->OUT .= "\t" . 'exten => _X.,n,GoToIf($["${myClusterOclo}" = "CLOSED"]?' .
            $myClusterId . '${CALLERID(num)}closedcos,${EXTEN},1:' .
            $myClusterId . '${CALLERID(num)}opencos,${EXTEN},1)' . "\n\n";
    }
}    

		
private function genExtensionsEndpoints()
{

    foreach ($this->cluster as $row) {
        $this->OUT .= "\n; Tenant - " . $row['pkey'] . "\n";

        $this->OUT .= "[" . $row['shortuid'] . "]\n";

        $this->OUT .= "\tinclude => park-" . $row['shortuid'] . "\n";
        $this->OUT .= "\tinclude => internal-presets\n";
        $this->OUT .= "\tinclude => withhold_clid\n";

        $this->OUT .= "\n";
		
		try {
			$sql = "SELECT * FROM appl WHERE cluster='" . $row['shortuid'] . "' ORDER BY pkey";
			$qRes = $this->dbh->query($sql);
			$this->appl = $qRes->fetchAll();
			$qRes = NULL;
		} catch (PDOException $e) {
			$errorMsg = $e->getMessage();
			return $errorMsg;
		}

        // Do not reuse $row — it is the tenant/cluster row for the rest of this loop.
        // Appl rows are already filtered to this cluster in the SQL above.
        foreach ($this->appl as $applrow) {
            if ($applrow['span'] == "Both" || $applrow['span'] == "Internal") {
                $this->OUT .= "\tinclude => " . $applrow['pkey'] . "\n";
            }
        }

        if (!empty($row['localarea']) && !empty($row['localdplan'])) {
            $this->OUT .= "\texten => " . $row['localdplan'] . ",1,GoTo(" . $row['localarea'] . "\${EXTEN},1)\n";
        }
/**
 * Placeholder
 * 
 * 				if (!empty($row['operator'])) {
					$this->OUT .= "\texten => 0,1,GoTo(00,1)\n";
				}
 * 
 *  
 */
				
    	if ($row['pkey'] == "default") 
        {
//			Master timers only accessible to the default cluster   
	        $this->OUT .= <<<HERE
;
;   Visual open/close MASTER throw (AstDB STAT/OCSTAT: CLOSED force closed; AUTO resume schedule;
;   CAGI also accepts day-part mode tokens in OCSTAT e.g. lunch)
;
	exten => MASTER,hint,Custom:MASTER

	exten => MASTER,1,Set(state=\${DB(STAT/OCSTAT)})
	exten => MASTER,n,GoToIf(\$["\${state}" = "AUTO"]?closeup:openup)

	exten => MASTER,n(closeup),Set(DB(STAT/OCSTAT)=CLOSED)
	exten => MASTER,n,Set(DEVICE_STATE(Custom:MASTER)=INUSE)
	exten => MASTER,n,Playback(activated)
	exten => MASTER,n,Hangup

	exten => MASTER,n(openup),Set(DB(STAT/OCSTAT)=AUTO)
	exten => MASTER,n,Set(DEVICE_STATE(Custom:MASTER)=NOT_INUSE)
	exten => MASTER,n,Playback(de-activated)
	exten => MASTER,n,Hangup

	exten => *30*,1,Authenticate(\${SYSPASS})
	exten => *30*,n,GoTo(MASTER,openup)

	exten => *31*,1,Authenticate(\${SYSPASS})
	exten => *31*,n,GoTo(MASTER,closeup)

HERE;
	    }

				// Visual open/close tenant throw

		$this->OUT .= <<<HERE
;
;   Visual open/close tenant throw
;	
HERE;

        $this->OUT .= "\n";
        $this->OUT .= "\texten => " . $row['pkey'] . ",hint,Custom:" . $row['pkey'] . "\n\n";
        $this->OUT .= "\texten => " . $row['pkey'] . ",1,Set(state=\${DB(" . $row['pkey'] . "/OCSTAT)})\n";
        $this->OUT .= "\texten => " . $row['pkey'] . ",n,GoToIf(\$[\"\${state}\" = \"AUTO\"]?" . $row['pkey'] . "close:" . $row['pkey'] . "open)\n";
        $this->OUT .= "\n";
        $this->OUT .= "\texten => " . $row['pkey'] . ",n(" . $row['pkey'] . "close),Set(DB(" . $row['pkey'] . "/OCSTAT)=CLOSED)\n";
        $this->OUT .= "\texten => " . $row['pkey'] . ",n,Set(DEVICE_STATE(Custom:" . $row['pkey'] . ")=INUSE)\n";
        $this->OUT .= "\texten => " . $row['pkey'] . ",n,Playback(activated)\n";
        $this->OUT .= "\texten => " . $row['pkey'] . ",n,Hangup\n";
        $this->OUT .= "\n";
        $this->OUT .= "\texten => " . $row['pkey'] . ",n(" . $row['pkey'] . "open),Set(DB(" . $row['pkey'] . "/OCSTAT)=AUTO)\n";
        $this->OUT .= "\texten => " . $row['pkey'] . ",n,Set(DEVICE_STATE(Custom:" . $row['pkey'] . ")=NOT_INUSE)\n";
        $this->OUT .= "\texten => " . $row['pkey'] . ",n,Playback(de-activated)\n";
        $this->OUT .= "\texten => " . $row['pkey'] . ",n,Hangup\n";
        $this->OUT .= "\n";
        $this->OUT .= "\texten => *33*,1,GoTo(" . $row['pkey'] . ',' . $row['pkey'] . "open)\n";
        $this->OUT .= "\texten => *34*,1,GoTo(" . $row['pkey'] . ',' . $row['pkey'] . "close)\n";
        $this->OUT .= "\n";
    //
    //  pickup marks
    //

        $this->OUT .= "\n\texten => _*8XX.,1,Pickup(\${EXTEN}@PICKUPMARK)\n\n";

        $this->OUT .= <<<HERE
;
;   Outbound Routes 
;	
HERE;

        $this->OUT .= "\n";

		try {
			$sql = "SELECT * FROM route WHERE cluster='" . $row['shortuid'] . "' ORDER BY pkey";
			$qRes = $this->dbh->query($sql);
			$route = $qRes->fetchAll();
			$qRes = NULL;
		} catch (PDOException $e) {
			$errorMsg = $e->getMessage();
			return $errorMsg;
		}
        foreach ($route as $routerow) {
            if ($routerow['active'] == "YES") {
                $routerow['dialplan'] = preg_replace('/\s+/', " ", $routerow['dialplan']);
                $routerow['dialplan'] = preg_replace('/\s*$/', "", $routerow['dialplan']);
                $dialplan = explode(" ", $routerow['dialplan']);
                foreach ($dialplan as $plan) {
                    $this->OUT .= "\texten => " . $plan . ",1,agi(" . SYSAGI . ",OutRoute," . $routerow['pkey'] . "," . $routerow['cluster'] . ",,,)\n";
                }
            }
        }
    $this->OUT .= <<<HERE
;
;   Direct trunk seize codes (if any)
;	
HERE;
        $this->OUT .= "\n";

		try {
			$sql = "SELECT * FROM trunks WHERE cluster='" . $row['shortuid'] . "' ORDER BY pkey";
			$qRes = $this->dbh->query($sql);
			$trunk = $qRes->fetchAll();
			$qRes = NULL;
		} catch (PDOException $e) {
			$errorMsg = $e->getMessage();
			return $errorMsg;
		}
        foreach ($trunk as $linerow) {
            if ($linerow['active'] == "YES" && $linerow['match'] != "") {
                $this->OUT .= "\texten => _" . $linerow['match'] . "X.,1,agi(" . SYSAGI . ",OutTrunk," . $linerow['pkey'] . "," . $linerow['cluster'] . ",,,)\n";
            }
        }
        /*
         * Tenant short dial (fleet): fixed-width dial prefix + fixed remainder = dest ext_len → PrefixDial.
         * Pattern _81XXXX (not open _81X.). Skip if prefix+dest_len ≤ caller ext_len (length namespace).
         * Dest ext_len from local cluster (target_cluster / target_fqdn); else caller ext_len.
         */
        if ($this->isFleetMode()) {
            $this->OUT .= <<<HERE
;
;   Dial prefixes (tenant short dial → PrefixDial via Egress/SBC)
;	
HERE;
            $this->OUT .= "\n";
            $callerExtLen = 3;
            if (isset($row['ext_len']) && is_numeric($row['ext_len'])) {
                $n = (int) $row['ext_len'];
                if ($n >= 3 && $n <= 5) {
                    $callerExtLen = $n;
                }
            }
            try {
                $sql = "SELECT pkey, target_fqdn, target_cluster FROM dialalias WHERE cluster='" . $row['shortuid'] . "' AND active='YES' ORDER BY pkey";
                $qRes = $this->dbh->query($sql);
                $aliases = $qRes ? $qRes->fetchAll() : [];
                $qRes = NULL;
                foreach ($aliases as $aliasrow) {
                    $prefix = isset($aliasrow['pkey']) ? trim((string) $aliasrow['pkey']) : '';
                    if ($prefix === '' || !preg_match('/^\d{2,4}$/', $prefix)) {
                        continue;
                    }
                    $destExtLen = $this->resolveDialTargetExtLen($aliasrow, $callerExtLen);
                    if ((strlen($prefix) + $destExtLen) <= $callerExtLen) {
                        continue;
                    }
                    $mask = str_repeat('X', $destExtLen);
                    $this->OUT .= "\texten => _" . $prefix . $mask . ",1,agi(" . SYSAGI . ",PrefixDial," . $prefix . "," . $row['shortuid'] . ",,,)\n";
                }
            } catch (PDOException $e) {
                if (stripos($e->getMessage(), 'no such table') === false) {
                    return $e->getMessage();
                }
            }
        }
        $this->OUT .= <<<HERE
;
;   ACD objects (page, callgroup, queue) 
;	
HERE;

        $this->OUT .= "\n";
        // Queues

		try {
			$sql = "SELECT * FROM queue WHERE cluster='" . $row['shortuid'] . "' ORDER BY pkey";
			$qRes = $this->dbh->query($sql);
			$queue = $qRes->fetchAll();
			$qRes = NULL;
		} catch (PDOException $e) {
			$errorMsg = $e->getMessage();
			return $errorMsg;
		}

        foreach ($queue as $qrow) {

            $this->OUT .= "\n;   Name: " . $qrow['name'] . " - " .$qrow['description']. "\n";
            $this->OUT .= "\texten => " . $qrow['pkey'] . ",1,Answer()\n";
            $OUTstring =  "\texten => " . $qrow['pkey'] . ",n,Queue(";
            $OUTstring .= $qrow['shortuid'];
            $OUTstring .= ',';
            $OUTstring .= $qrow['options'];
            // Queue(name,options,URL,announceoverride,timeout,AGI) — timeout = Caller Max Wait
            $OUTstring .= ',,,';
            $callerTo = isset($qrow['caller_timeout']) ? (int) $qrow['caller_timeout'] : 0;
            if ($callerTo > 0) {
                $OUTstring .= $callerTo;
            }
            $OUTstring .= ',';
            if ($qrow['devicerec'] != 'None') {
                $OUTstring .= SYSAGI;
            }
            $OUTstring .= ")\n";
            if ($qrow['greetnum'] != 'None') {
                $this->OUT .= "\texten => " . $qrow['pkey'] . ",n,Playback(" . SOUNDIR . $row['pkey'] . "/usergreeting" . $qrow['greetnum'] . ")\n";
            }
            $this->OUT .= $OUTstring;

// outcome processing... dialable: numeric endpoint, or *{ext} leave-voicemail (SARK).
            $outcome = isset($qrow['outcome']) ? trim((string) $qrow['outcome']) : '';
            if ($outcome !== '' && strcasecmp($outcome, 'None') !== 0
                && (is_numeric($outcome) || preg_match('/^\*\S+$/', $outcome))) {
                $this->OUT .= "\texten => " . $qrow['pkey'] . ",n,GoTo(" . $outcome . ",1)\n";
            }
        }

    $this->OUT .= <<<HERE
;
;   Auto-attendant (IVR) objects 
;	
HERE;

        $this->OUT .= "\n";

		try {
		$sql = "SELECT * FROM ivrmenu WHERE cluster='" . $row['shortuid'] . "' ORDER BY pkey";
        $qRes = $this->dbh->query($sql);
        $ivr = $qRes->fetchAll();
		} catch (PDOException $e) {
			$errorMsg = $e->getMessage();
			return $errorMsg;
		}

        $qRes = NULL;
        foreach ($ivr as $irow) {
            $this->OUT .= "\n;   Name: " . $irow['name'] . " - " .$irow['description']. "\n";
            $this->OUT .= "\texten => " . $irow['pkey'] . ",1,Answer()\n";
            $this->OUT .= "\texten => " . $irow['pkey'] . ",n,agi(" . SYSAGI . ",IVR," . $irow['pkey'] . "," . $irow['cluster'] . ",,,)\n";					
        }
        $this->OUT .= <<<HERE
;
;   Our registered endpoints (phones) 
;	
HERE;

        $this->OUT .= "\n";

		try {
			$sql = "SELECT * FROM ipphone where cluster = '" . $row['shortuid'] . "' ORDER BY pkey";
			$qRes = $this->dbh->query($sql);
			$phones = $qRes->fetchAll();
			$qRes = NULL;
		} catch (PDOException $e) {
			$errorMsg = $e->getMessage();
			return $errorMsg;
		}

        foreach ($phones as $phone) {
            $this->OUT .= ";  Extension: " . $phone['pkey'] . " - " . "SIP Endpoint: " . $phone['shortuid'] . "\n";
            $this->OUT .= "\texten => " . $phone['pkey'] . ",hint,PJSIP/" . $phone['shortuid'] . "\n";
            $this->OUT .= "\texten => " . $phone['pkey'] . ",1,GoTo(" . $phone['shortuid'] . ",1)\n";
/**
 *  Phase G: LepDial PreDial (Set PBX3_DIAL) → Dial → PostDial.
 *  Skip Dial if PBX3_DIAL empty (CFIM/VM early exit). Skip PostDial on ANSWER/CANCEL
 *  (avoid dead-AGI cold start). Deploy new pbx3cagi before Commit.
 */
            $this->OUT .= "\texten => " . $phone['shortuid'] . ",1,agi(" . SYSAGI . ",LepDial,," . $phone['cluster'] . ",,,)\n";
            $this->OUT .= "\tsame => n,GotoIf(\$[\"\${PBX3_DIAL}\"=\"\"]?" . $phone['shortuid'] . "-done)\n";
            $this->OUT .= "\tsame => n,Dial(\${PBX3_DIAL})\n";
            $this->OUT .= "\tsame => n,GotoIf(\$[\"\${DIALSTATUS}\"=\"ANSWER\"]?" . $phone['shortuid'] . "-done)\n";
            $this->OUT .= "\tsame => n,GotoIf(\$[\"\${DIALSTATUS}\"=\"CANCEL\"]?" . $phone['shortuid'] . "-done)\n";
            $this->OUT .= "\tsame => n,agi(" . SYSAGI . ",PostDial," . $phone['shortuid'] . "," . $phone['cluster'] . ",,,)\n";
            $this->OUT .= "\tsame => n(" . $phone['shortuid'] . "-done),Hangup()\n";
/**
 *  Queue members: Local/Q{ext}@tenant for desk extensions; Local/{pstn}@tenant for
 *  non-extension tokens (OutRoute). See genQueues.
 */
            $this->OUT .= "\texten => Q" . $phone['pkey'] . ",1,agi(" . SYSAGI . ",Dial," . $phone['shortuid'] . "," . $phone['cluster'] . ",queue,,)\n";
            $this->OUT .= "\texten => Q" . $phone['pkey'] . ",n,Dial(\${PBX3_DIAL})\n";

            if ($phone['dvrvmail'] != "None") {
                if ($phone['dvrvmail'] == "") {
                    $phone['dvrvmail'] = $phone['pkey'];							
                }
                $this->OUT .=  "\texten => *" . $phone['pkey'] . ",1,Voicemail(" . $phone['dvrvmail'] . "@" . $row["shortuid"]  . ",su)\n";
                $this->OUT .=  "\texten => vm" . $phone['pkey'] . ",hint,Custom:vm" . $phone['pkey'] . "\n";
                $this->OUT .=  "\texten => vm" . $phone['pkey'] . ",1,VoicemailMain(" . $phone['pkey'] . "@" . $row["shortuid"]  .  ")\n";
            }

            $this->OUT .= "\n";
    }

/**
 * 	Handle greetings here
 */
$this->OUT .= <<<HERE
;
;   Greetings playback extensions (if any)
;	
HERE;

        $this->OUT .= "\n";

		try {
        $sql = "SELECT * FROM greeting WHERE cluster='" . $row['shortuid'] . "' ORDER BY pkey";
			$GRes = $this->dbh->query($sql);
			$greetings = $GRes->fetchAll();
			$GRes = NULL;
		} catch (PDOException $e) {
			$errorMsg = $e->getMessage();
			return $errorMsg;
		}

        foreach ($greetings as $greeting) {
            $this->OUT .= "\texten => " . $greeting['pkey'] . ",1,Playback(" . SOUNDIR . $greeting ['filename'] . ")\n";
        }

/**
 *  Conference bridges (if any)
 */
$this->OUT .= <<<HERE
;
;   Conference bridges (if any)
;
HERE;

        $this->OUT .= "\n";
        $this->confBridge($row['shortuid']);



$this->OUT .= <<<HERE
;
;   short codes & vmail
;	
HERE;

        $this->OUT .= "\n";
        $this->OUT .= "\texten => *50*,1,VoiceMailMain(\${CALLERID(num)}@" . $row["shortuid"] . ")\t;Voicemail Retrieve\n";
        $this->OUT .= "\texten => *51*,1,VoiceMailMain(@" . $row["shortuid"] . ")\t;General Voicemail Retrieve\n";
    }
}

    private function genExtensionsCosTests()
    {


		$this->OUT .= <<<HERE
;
;   CoS inline filters (if any)
;

HERE;
		if (($this->globals['cosstart'] ?? '') == "ON") {
			$orideopenarray = array();
			$orideclosedarray = array();
			//
			//      select the overrides first
			//

			try {
				$sql = "SELECT * FROM cos ORDER BY pkey";
				$qRes = $this->dbh->query($sql);
				$cos = $qRes->fetchAll();
				$qRes = NULL;
			} catch (PDOException $e) {
				$errorMsg = $e->getMessage();
				return $errorMsg;
			}
			foreach ($cos as $mycos) {
				if ($mycos['orideopen'] == 'YES') {
					$orideopenarray[$mycos['pkey']] =	"YES";
				}
				if ($mycos['orideclosed'] == 'YES') {
					$orideclosedarray[$mycos['pkey']] =	"YES";
				}
			}
			//
			//		now do the process 
			//
			try {							
				$sql = "SELECT * FROM ipphone ORDER BY pkey";
				$qRes = $this->dbh->query($sql);
				$cosphone = $qRes->fetchAll();
				$qRes = NULL;
			} catch (PDOException $e) {
				$errorMsg = $e->getMessage();
				return $errorMsg;
			}
			foreach ($cosphone as $IPphone) {
				$myCluster = $IPphone['cluster'];
/*
				if ($myCluster == 'default') {
					$myCluster = 'qrxvtmny';
				} 
*/
				$this->OUT .= "[" . $myCluster . $IPphone['pkey'] . "opencos]\n";


				//			$this->OUT .= "\tinclude => Emergency\n"; 
				//			
				//			print the overrides
				//			 
				foreach ($orideopenarray as $key => $value) {
					$this->OUT .= "\tinclude => " . $key . "\n";
				}

				try {
					$sql = 	"SELECT cos_pkey FROM ipphonecosopen where ipphone_pkey='" . $IPphone['pkey'] . "'";
					$qRes = $this->dbh->query($sql);
					$cosopen = $qRes->fetchAll();
					$qRes = NULL;
				} catch (PDOException $e) {
					$errorMsg = $e->getMessage();
					return $errorMsg;
				}

				foreach ($cosopen as $coskeys) {
					//
					//          don't print if already overridden
					// 
if (empty($orideopenarray[$coskeys['cos_pkey']])) {
					$this->OUT .= "\tinclude => " . $coskeys['cos_pkey'] . "\n";
					}
				}

				$this->OUT .= "\tinclude => " . $myCluster . $IPphone['pkey'] . "Cosend\n";
				$this->OUT .= "[" . $myCluster . $IPphone['pkey'] . "closedcos]\n";
				
				foreach ($orideclosedarray as $key => $value) {
					$this->OUT .= "\tinclude => " . $key . "\n";
				}

				try {
					$sql = 	"SELECT cos_pkey FROM ipphonecosclosed where ipphone_pkey='" . $IPphone['pkey'] . "'";
					$qRes = $this->dbh->query($sql);
					$cosclosed = $qRes->fetchAll();
					$qRes = NULL;
				} catch (PDOException $e) {
					$errorMsg = $e->getMessage();
					return $errorMsg;
				}

				foreach ($cosclosed as $coskeys) {
					//
					//          don't print if already overridden
					// 
if (empty($orideclosedarray[$coskeys['cos_pkey']])) {
					$this->OUT .= "\tinclude => " . $coskeys['cos_pkey'] . "\n";
					}
				}
				//			$this->OUT .= "\tinclude => " . $myCluster . "Cosend\n";
				$this->OUT .= "\tinclude => " . $myCluster . $IPphone['pkey'] . "Cosend\n";

				//			$this->OUT .= '[' . $myCluster . $iKey . "Cosend]\n";
				$this->OUT .= '[' . $myCluster . $IPphone['pkey'] . "Cosend]\n";

				//			$this->OUT .= '[' . $myCluster ."Cosend]\n";  
				$this->OUT .= "\texten => _X.,1,GoTo($myCluster,\${EXTEN},1)\n\n";
			}
		}

		foreach ($cos as $COS) {
			$this->OUT .= "[" . $COS['pkey'] . "]\n";
			$COS['dialplan'] = preg_replace('/\s+/', " ", $COS['dialplan']);
			$COS['dialplan'] = preg_replace('/\s*$/', "", $COS['dialplan']);
			$dialplan = explode(" ", $COS['dialplan']);
			foreach ($dialplan as $plan) {
				$this->OUT .= "\texten => $plan,1,Playtones(congestion)\n";
				$this->OUT .= "\texten => $plan,2,Hangup\n";
			}
		}
}

    private function genExtensionsFromPeers()
    {
			//
			//  begin Ingress (inbound DDI pool) 
			//	

    $this->OUT .= <<<HERE

[from-external]   ;Compatibility
	include => Ingress

[from-trunk]   ;Compatibility
	include => Ingress

[mainmenu]   ;Compatibility
	include => Ingress	

HERE;

		/*
		 * Dial b() pre-dial on outbound PJSIP (PAI + Alert-Info).
		 * PJSIP_HEADER only sticks on the channel that will send the INVITE.
		 */
		$this->OUT .= "\n[pbx3-pre-dial]\n";
		$this->OUT .= "\texten => s,1,NoOp(pbx3 pre-dial PAI=\${PBX3_RETURN_AOR} Alert=\${PBX3_ALERT_INFO})\n";
		$this->OUT .= "\tsame => n,GotoIf(\$[\"\${PBX3_RETURN_AOR}\"=\"\"]?alert)\n";
		$this->OUT .= "\tsame => n,Set(PJSIP_HEADER(remove,P-Asserted-Identity)=)\n";
		$this->OUT .= "\tsame => n,Set(PJSIP_HEADER(add,P-Asserted-Identity)=<sip:\${PBX3_RETURN_AOR}>)\n";
		$this->OUT .= "\tsame => n(alert),GotoIf(\$[\"\${PBX3_ALERT_INFO}\"=\"\"]?done)\n";
		$this->OUT .= "\tsame => n,Set(PJSIP_HEADER(add,Alert-Info)=\${PBX3_ALERT_INFO})\n";
		$this->OUT .= "\tsame => n(done),Return()\n";
		$this->OUT .= "\n";
		/* Alias for dial strings still using b(pbx3-site-pai^s^1) */
		$this->OUT .= "[pbx3-site-pai]\n";
		$this->OUT .= "\texten => s,1,Goto(pbx3-pre-dial,s,1)\n";
		$this->OUT .= "\n";

		/*
		 * Fleet only: Egress identify → SbcDomainRoute.
		 * PrefixDial / site dial home path: R-URI user@tenant.fqdn after SBC
		 * usrloc miss → dispatcher. Map FQDN → local tenant context; else DID Ingress.
		 */
		if ($this->isFleetMode()) {
			$this->OUT .= "\n[SbcDomainRoute]\n";
			$this->OUT .= "; Carrier +E164 → DID pool (do not treat as site-dial extension)\n";
			$this->OUT .= "\texten => _+X.,1,Goto(Ingress,\${EXTEN},1)\n";
			$this->OUT .= "; Digit R-URI: route by Request-URI host when it is a known tenant FQDN\n";
			$this->OUT .= "\texten => _X.,1,NoOp(SBC domain route \${EXTEN})\n";
			$this->OUT .= "\tsame => n,Set(__PBX3_SITE_DIAL=YES)\n";
			/*
			 * Magrathea: X-PBX3-Pres-Num = presentation digits (Site Group:
			 * routing_prefix+ext); PAI = return AoR (suid@fqdn).
			 * Prefer Pres-Num for CALLERID display + digit callback. Do not
			 * stuff PAI into CALLERID or __PBX3_RETURN_AOR when Pres-Num is
			 * present — SiteRing would re-add PAI and desks show suid@domain.
			 * No Pres-Num: fall back to PAI in CLID + RETURN_AOR (Path 1).
			 */
			$this->OUT .= "\tsame => n,Set(PBX3_PRES=\${PJSIP_HEADER(read,X-PBX3-Pres-Num)})\n";
			$this->OUT .= "\tsame => n,Set(PBX3_PAI=\${PJSIP_HEADER(read,P-Asserted-Identity)})\n";
			$this->OUT .= "\tsame => n,GotoIf(\$[\"\${PBX3_PRES}\"=\"\"]?sbr_no_pres)\n";
			$this->OUT .= "\tsame => n,Set(CALLERID(num)=\${PBX3_PRES})\n";
			$this->OUT .= "\tsame => n,Goto(sbr_pres_done)\n";
			$this->OUT .= "\tsame => n(sbr_no_pres),GotoIf(\$[\"\${PBX3_PAI}\"=\"\"]?sbr_no_pai)\n";
			$this->OUT .= "\tsame => n,Set(PBX3_PAI_USER=\${PJSIP_PARSE_URI(\${PBX3_PAI},user)})\n";
			$this->OUT .= "\tsame => n,Set(PBX3_PAI_HOST=\${PJSIP_PARSE_URI(\${PBX3_PAI},host)})\n";
			$this->OUT .= "\tsame => n,GotoIf(\$[\"\${PBX3_PAI_USER}\"=\"\" | \"\${PBX3_PAI_HOST}\"=\"\"]?sbr_no_pai)\n";
			$this->OUT .= "\tsame => n,Set(__PBX3_RETURN_AOR=\${PBX3_PAI_USER}@\${PBX3_PAI_HOST})\n";
			$this->OUT .= "\tsame => n,Set(CALLERID(num)=\${PBX3_PAI_USER}@\${PBX3_PAI_HOST})\n";
			$this->OUT .= "\tsame => n(sbr_pres_done),NoOp(site-dial CLID \${CALLERID(num)})\n";
			$this->OUT .= "\tsame => n(sbr_no_pai),Set(PBX3_RURI_HOST=\${PJSIP_PARSE_URI(\${CHANNEL(pjsip,request_uri)},host)})\n";
			try {
				$sql = "SELECT shortuid, fqdn FROM cluster WHERE fqdn IS NOT NULL AND TRIM(fqdn) != '' ORDER BY shortuid";
				$qRes = $this->dbh->query($sql);
				$tenants = $qRes ? $qRes->fetchAll() : [];
				$qRes = NULL;
				$instanceFqdn = '';
				$gq = $this->dbh->query("SELECT fqdn FROM globals LIMIT 1");
				$grow = $gq ? $gq->fetch(PDO::FETCH_ASSOC) : false;
				if ($grow && !empty($grow['fqdn'])) {
					$instanceFqdn = strtolower(trim((string) $grow['fqdn']));
				}
				foreach ($tenants as $trow) {
					$suid = isset($trow['shortuid']) ? trim((string) $trow['shortuid']) : '';
					$fqdn = isset($trow['fqdn']) ? strtolower(trim((string) $trow['fqdn'])) : '';
					if ($suid === '' || $fqdn === '' || !preg_match('/^[a-z0-9][a-z0-9.-]+\.[a-z]{2,}$/i', $fqdn)) {
						continue;
					}
					if ($instanceFqdn !== '' && $fqdn === $instanceFqdn) {
						continue;
					}
					// Escape dots for literal dialplan string compare
					$this->OUT .= "\tsame => n,GotoIf(\$[\"\${PBX3_RURI_HOST}\"=\"" . $fqdn . "\"]?" . $suid . ",\${EXTEN},1)\n";
				}
			} catch (PDOException $e) {
				// Keep route; fall through to Ingress on empty map
			}
			$this->OUT .= "\tsame => n,Goto(Ingress,\${EXTEN},1)\n";
			$this->OUT .= "\n";
		}

    $this->OUT .= <<<HERE
[Ingress]
        
HERE;

    $this->OUT .= "\n\n";
	$this->OUT .= <<<HERE
;
;   Incoming DDIs (if any)
;
	
HERE;
	$this->OUT .= "\n\n";
	try {
		$sql = "select * from appl";
		$qRes = $this->dbh->query($sql);
		$this->appl = $qRes->fetchAll();
		$qRes = NULL;
	} catch (PDOException $e) {
		$errorMsg = $e->getMessage();
		return $errorMsg;
	}

    foreach ($this->appl as $row) {
        if ($row['span'] == "Both" || $row['span'] == "External") {
            $this->OUT .= "\tinclude => " . $row['pkey'] . "\n";
        }
    }

	try {
		$sql = "select * from inroutes order by pkey ";
		$qRes = $this->dbh->query($sql);
		$inroutes = $qRes->fetchAll();
		$qRes = NULL;
	} catch (PDOException $e) {
		$errorMsg = $e->getMessage();
		return $errorMsg;
	}

    foreach ($inroutes as $row) {
        $this->OUT .= "\texten => " . $row['pkey'] . ",1,agi(" . SYSAGI . ",Ingress," . $row['pkey'] . "," . $row['cluster'] . ",,,)\n";
    }
    $this->OUT .= <<<HERE

	exten => i,1,Playtones(congestion)
	exten => i,2,wait(5)
	exten => i,3,HangUp

HERE;
    }

    private function genExtensionsFeatures() 
    {

    //
    //  Internal presets and withhold CLID
    //	include these from separate files
    //

    $this->OUT .= "\n#include extensions_presets.conf\n";
    $this->OUT .= "\n#tryinclude extensions_withhold_clid.conf\n";
    $this->OUT .= "\n#include extensions_park_timeout.conf\n";
			
    }

    private function genExtensionsCustomApps() 
    {

        $this->OUT .= <<<HERE

;
;#####################################################################
;
;	Customer Supplied Contexts below this line (if any).
;
;#####################################################################

HERE;

    //
    // Custom Apps
    //	
        $this->OUT .= "\n";

        foreach ($this->appl as $row) {
            if (!empty($row['active'])) {
                if ($row['active'] != "YES") {
                    continue;
                }
            }
            $this->OUT .= ";\n";
            $this->OUT .= ";\tCustomer Supplied Context " .  $row['pkey'] . "\n";
            $this->OUT .= ";\n";
            $this->OUT .= "[" .  $row['pkey'] . "]\n";
            $this->OUT .= $row['extcode'];
            $this->OUT .= ";\n";
        }
}

    private function confBridge($clstshortuid)
    {
        $profile = 'pbx3_user';

		try {
			$sql = "SELECT * FROM meetme WHERE cluster='" . $clstshortuid . "' ORDER BY pkey";
			$qRes = $this->dbh->query($sql);
			$meetme = $qRes->fetchAll();
			$qRes = NULL; 
		} catch (PDOException $e) {
			$errorMsg = $e->getMessage();
			return $errorMsg;
		}

        foreach ($meetme as $room) {
			if (!empty($room['active']) && strtoupper((string) $room['active']) !== 'YES') {
				continue;
			}
			$this->OUT .= "\texten => " . $room['pkey'] . ",1,NoOp(conference " . $room['pkey'] . ")\n";
			$this->OUT .= "\tsame => n,Answer(500)\n";
			if ($room['pin'] and $room['pin'] != "None") {
				$this->OUT .= "\tsame => n,Authenticate(" . $room['pin'] . ")\n";
			}		 
			if ($room['type'] == "hosted" ) {			
				$profile = 'pbx3_hosted_user';
			}	
			$this->OUT .= "\tsame => n,ConfBridge(\${EXTEN},,$profile)\n";
			$this->OUT .= "\tsame => n,Hangup()\n";
        }	
    }
}