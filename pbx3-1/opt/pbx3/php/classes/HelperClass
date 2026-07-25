<?php

// Helper class
// Developed by CoCo
// Copyright (C) 2024 CoCoKraft.com
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
//

// require_once __DIR__ . "/../config.php";

/**
 *  A bunch of primarily db and/or backend, helpers
 */
 
Class helper {

	private $gen;


/**
 * __construct
 *  Nothing to see here
 */
function __construct(){
	
}

/**
 * Human readable shortuid generator (shortuid in the DB).
 * Uses idpwgen binary; default 6 chars from DEFAULT_CHARSET.
 */

private static $DEFAULT_CHARSET = '0123456789bcdfghjkmnpqrstvwxyz';
/* no vowels, no similar-looking chars (0/O, 1/I/l); low chance of accidental rude words */

/** Path to idpwgen binary (from config.php when available). */
private static function idpwgenPath() {
	return defined('IDPWGEN') ? IDPWGEN : '/opt/pbx3/golang/idpwgen';
}

/**
 * Run idpwgen and return validated output.
 * @param int    $length
 * @param string $charset
 * @return string generated ID
 * @throws \RuntimeException on failure
 */
private static function runIdpwgen($length, $charset) {
	$path = self::idpwgenPath();
	if (!is_executable($path)) {
		throw new \RuntimeException('idpwgen not executable: ' . $path);
	}
	$cmd = $path . ' -length ' . (int) $length . ' -charset ' . escapeshellarg($charset);
	$desc = [1 => ['pipe', 'w'], 2 => ['pipe', 'w']];
	$proc = @proc_open($cmd, $desc, $pipes, null, null, ['bypass_shell' => true]);
	if (!is_resource($proc)) {
		throw new \RuntimeException('idpwgen proc_open failed');
	}
	$stdout = stream_get_contents($pipes[1]);
	$stderr = stream_get_contents($pipes[2]);
	fclose($pipes[1]);
	fclose($pipes[2]);
	$code = proc_close($proc);
	if ($code !== 0) {
		error_log('idpwgen exit ' . $code . ': ' . trim($stderr));
		throw new \RuntimeException('idpwgen failed (exit ' . $code . ')');
	}
	$uid = trim($stdout);
	if (strlen($uid) !== $length) {
		throw new \RuntimeException('idpwgen wrong length: got ' . strlen($uid) . ', expected ' . $length);
	}
	$charsetArr = array_flip(str_split($charset));
	for ($i = 0; $i < strlen($uid); $i++) {
		if (!isset($charsetArr[$uid[$i]])) {
			throw new \RuntimeException('idpwgen invalid character in output');
		}
	}
	return $uid;
}

/**
 * @param int    $length  default 6 (shortuid)
 * @param string $charset default DEFAULT_CHARSET
 * @return string
 */
public static function generate($length = 6, $charset = '')
{
	$charset = $charset ?: self::$DEFAULT_CHARSET;
	$out = self::runIdpwgen($length, $charset);
	return strtolower($out);
}

/**
 * [sysCommit perform a system Commit - i.e. generate from local to live]
 * @return NULL
 */
public function sysCommit() {

	require_once GENCLASS;

// ask the helper to run a regen for us.
   $this->logit(" commit - starting task", 5 ); 

	$this->gen = new genAsteriskObjects;
	$this->gen->genAsterisk();


	$this->logit(" commit - ended task", 5 );

/*
 * take a snapshot
 */ 
	$rc = $this->request_syscmd ("/bin/sh " . SCRIPTS . "/snap.sh");

/*
 * reload asterisk
 */
	$rc = $this->request_syscmd ("asterisk -rx 'reload'");

/*
 * turn off commit
 */	
	
	if (file_exists(CACHE . "/commitflag")) {
		system ("/bin/rm -rf " . CACHE . "/commitflag");
	} 


	return;
}

/**
 * commitOn
 *
 * @return void
 */
public function commitOn () {
//turn the commit lamp on

	system ("sudo /bin/touch " . CACHE . "/commitflag");
	return;
}
	
public function request_syscmd ($data) {

//establish connection to the daemon
 
	$fp = fsockopen( "127.0.0.1", 7601, $errno, $errdesc, 1)
		or die("Connection to 127.0.0.1:7601 failed"); 
	$ret = null;
// read the ack sent by server.
	$ack[] = fgets($fp, 8192);
    $this->logit(" request_syscmd sending -> $data", 5 );
	fputs($fp, "$data\n"); 
//	while( ! preg_match(' /EOT/ ',$ret)) { 
	while (1) {
		$ret .= fgets($fp, 8192);
		if ( ! preg_match(' /EOT/ ',$ret)) { 
			break;
		} 
	} 
	fclose($fp);
	return ($ret);

}

public function check_pid()  {

   	if  (`/bin/ps -e | /bin/grep asterisk | /bin/grep -v grep`) {
   		return true;
   	}

	return false;
}

/**
 * PJSIP functions create/get/set/destroy
 */

/**
 * Copy pjsip file template to named trunk file
 * @param  array $tuple Trunk row
 * @return bool  
 */
/**
 * Ensure trunks dir for overlays (stock tmpl is never copied).
 * @param  array $tuple Trunk row (unused; signature kept for callers)
 * @return bool
 */
public function createPjsipTrunkInstance($tuple) {

	if (!is_dir(ASTTRUNKS)) {
		$this->request_syscmd("/bin/mkdir -p " . ASTTRUNKS . " >/dev/null 2>&1");
		$this->request_syscmd("/bin/chown asterisk:asterisk " . ASTTRUNKS . " >/dev/null 2>&1");
	}
	return true;
}

/**
 * Resolve stock trunk tmpl path from trunk row.
 * @param  array $tuple
 * @return string
 */
private function pjsipTrunkTemplateFile($tuple) {

	$pkey = (string)($tuple['pkey'] ?? '');
	if ($pkey === 'Egress' || $pkey === 'EgressFailover') {
		return PJSIP_TRUNK_EGRESS_TEMPLATE;
	}
	switch ($tuple['pjsipreg'] ?? '') {
		case 'SND':
			return PJSIP_TRUNK_SNDREG_TEMPLATE;
		case 'RCV':
			return PJSIP_TRUNK_RCVREG_TEMPLATE;
		default:
			return PJSIP_TRUNK_TRUSTED_TEMPLATE;
	}
}

/**
 * Stock trunk tmpl plus optional thin overlay (pre-xlate).
 * Home of record: $dbOverlay (trunks.pjsip_overlay). File under trunks/ is
 * fallback when DB overlay is empty. Legacy {pkey}_trunk.conf is ignored.
 * @param  array       $tuple Trunk row
 * @param  string|null $dbOverlay thin overlay text from trunk row
 * @return string|false
 */
public function getPjsipTrunkInstance($tuple, $dbOverlay = null) {

	$this->createPjsipTrunkInstance($tuple);
	$templateFile = $this->pjsipTrunkTemplateFile($tuple);
	if (!file_exists($templateFile)) {
		return false;
	}
	$buff = file_get_contents($templateFile);
	if ($buff === false) {
		return false;
	}

	$pkey = (string)($tuple['pkey'] ?? '');
	$overlay = null;
	if ($dbOverlay !== null && trim((string) $dbOverlay) !== '') {
		$overlay = (string) $dbOverlay;
	} else {
		$overlayFile = ASTTRUNKS . '/' . $pkey . '_' . PJSIP_TRUNK_OVERLAY;
		if (file_exists($overlayFile) && filesize($overlayFile) > 0) {
			$fileOverlay = file_get_contents($overlayFile);
			if ($fileOverlay !== false && trim($fileOverlay) !== '') {
				$overlay = $fileOverlay;
			}
		}
	}
	if ($overlay !== null) {
		$buff = $this->mergePjsipPhoneOverlay($buff, $overlay);
	}
	return $buff;
}

/**
 * Write thin per-trunk overlay (not a full tmpl clone).
 * @param  string $key trunk pkey
 * @param  string $data overlay fragment
 * @return bool
 */
public function setPjsipTrunkInstance($key, $data) {

	$this->createPjsipTrunkInstance(array('pkey' => $key));
	$targetFile = ASTTRUNKS . '/' . $key . '_' . PJSIP_TRUNK_OVERLAY;
	$fh = fopen($targetFile, 'w') or die("Could not open file $targetFile!");
	fwrite($fh, $data) or die("Could not write to file $targetFile !");
	fclose($fh);
	$this->request_syscmd("/bin/chown asterisk:asterisk $targetFile >/dev/null 2>&1");
	$this->request_syscmd("/bin/chmod 664 $targetFile >/dev/null 2>&1");
	return true;
}

/**
 * Delete trunk overlay (and legacy frozen conf if present).
 * @param  string $key trunk pkey
 * @return mixed
 */
public function deletePjsipTrunkInstance($key) {

	$rc = false;
	$overlayFile = ASTTRUNKS . '/' . $key . '_' . PJSIP_TRUNK_OVERLAY;
	if (file_exists($overlayFile)) {
		$rc = $this->request_syscmd("/bin/rm $overlayFile >/dev/null 2>&1");
	}
	$legacyFile = ASTTRUNKS . '/' . $key . '_' . PJSIP_TRUNK;
	if (file_exists($legacyFile)) {
		$rc = $this->request_syscmd("/bin/rm $legacyFile >/dev/null 2>&1");
	}
	return $rc;
} 

/**
 * Ensure endpoints dir for phone overlays (stock tmpl is never copied).
 * Extension create paths may call this; it is a harmless success.
 * @param  string $key phone shortuid
 * @return bool
 */
public function createPjsipPhoneInstance($key) {

	if (!is_dir(ASTENDPOINTS)) {
		$this->request_syscmd("/bin/mkdir -p " . ASTENDPOINTS . " >/dev/null 2>&1");
		$this->request_syscmd("/bin/chown asterisk:asterisk " . ASTENDPOINTS . " >/dev/null 2>&1");
	}
	return true;
}

/**
 * Stock pjsip_phone.tmpl plus optional thin overlay (pre-xlate).
 * Overlay keys replace matching keys in the same type= object; absent keys are added.
 * Home of record: $dbOverlay (ipphone.pjsip_overlay). File under endpoints/ is
 * fallback only when DB overlay is empty. Legacy {key}_phone.conf is ignored.
 * @param  string      $key phone shortuid
 * @param  string|null $dbOverlay thin overlay text from extension row
 * @return string|false
 */
public function getPjsipPhoneInstance($key, $dbOverlay = null) {

	if (!file_exists(PJSIP_PHONE_TEMPLATE)) {
		return false;
	}
	$buff = file_get_contents(PJSIP_PHONE_TEMPLATE);
	if ($buff === false) {
		return false;
	}

	$overlay = null;
	if ($dbOverlay !== null && trim((string) $dbOverlay) !== '') {
		$overlay = (string) $dbOverlay;
	} else {
		$overlayFile = ASTENDPOINTS . '/' . $key . '_' . PJSIP_PHONE_OVERLAY;
		if (file_exists($overlayFile) && filesize($overlayFile) > 0) {
			$fileOverlay = file_get_contents($overlayFile);
			if ($fileOverlay !== false && trim($fileOverlay) !== '') {
				$overlay = $fileOverlay;
			}
		}
	}
	if ($overlay !== null) {
		$buff = $this->mergePjsipPhoneOverlay($buff, $overlay);
	}
	return $buff;
}

/**
 * Merge thin overlay into stock phone conf text (pre-xlate).
 * Match overlay sections to stock by type= (endpoint/auth/aor). For each overlay
 * key: replace if present in that object, else append. Overlay sections with a
 * type= not present in stock are appended whole.
 * @param  string $stock
 * @param  string $overlay
 * @return string
 */
private function mergePjsipPhoneOverlay($stock, $overlay) {

	$base = $this->parsePjsipConfSections($stock);
	$over = $this->parsePjsipConfSections($overlay);

	foreach ($over as $osec) {
		if ($osec['name'] === '' && $osec['type'] === null) {
			continue; // ignore preamble noise in overlay
		}
		$idx = $this->findPjsipSectionIndex($base, $osec);
		if ($idx === null) {
			$base[] = $osec;
			continue;
		}
		foreach ($osec['lines'] as $oline) {
			if ($oline['kind'] !== 'kv') {
				// comments / bare lines from overlay: append
				$base[$idx]['lines'][] = $oline;
				continue;
			}
			if (strcasecmp($oline['key'], 'type') === 0) {
				continue; // type used only for matching
			}
			$replaced = false;
			foreach ($base[$idx]['lines'] as $li => $bline) {
				if ($bline['kind'] === 'kv' && strcasecmp($bline['key'], $oline['key']) === 0) {
					$base[$idx]['lines'][$li] = $oline;
					$replaced = true;
					break;
				}
			}
			if (!$replaced) {
				$base[$idx]['lines'][] = $oline;
			}
		}
	}

	return $this->emitPjsipConfSections($base);
}

/**
 * Merge thin overlay into a flat key=value conf body (no [sections]).
 * Overlay keys replace matching keys in stock; absent keys are appended.
 * @param  string $stock
 * @param  string $overlay
 * @return string
 */
private function mergeFlatConfOverlay($stock, $overlay) {

	$stock = str_replace(array("\r\n", "\r"), "\n", $stock);
	$overlay = str_replace(array("\r\n", "\r"), "\n", $overlay);
	$lines = explode("\n", $stock);
	$byKey = array();
	$order = array();

	foreach ($lines as $i => $line) {
		$trimmed = trim($line);
		if ($trimmed !== '' && $trimmed[0] !== ';' && strpos($trimmed, '=') !== false) {
			$eq = strpos($trimmed, '=');
			$key = trim(substr($trimmed, 0, $eq));
			$byKey[strtolower($key)] = $i;
		}
		$order[] = $line;
	}

	foreach (explode("\n", $overlay) as $oline) {
		$trimmed = trim($oline);
		if ($trimmed === '' || $trimmed[0] === ';') {
			$order[] = $oline;
			continue;
		}
		if (strpos($trimmed, '=') === false) {
			$order[] = $oline;
			continue;
		}
		$eq = strpos($trimmed, '=');
		$key = trim(substr($trimmed, 0, $eq));
		$lk = strtolower($key);
		if (isset($byKey[$lk])) {
			$order[$byKey[$lk]] = $oline;
		} else {
			$byKey[$lk] = count($order);
			$order[] = $oline;
		}
	}

	return implode("\n", $order);
}

/**
 * @param  string $text
 * @return array list of sections: name, type, lines[]
 */
private function parsePjsipConfSections($text) {

	$text = str_replace(array("\r\n", "\r"), "\n", $text);
	$lines = explode("\n", $text);
	$sections = array();
	$cur = array('name' => '', 'type' => null, 'lines' => array());

	foreach ($lines as $line) {
		if (preg_match('/^\s*\[([^\]]+)\]\s*$/', $line, $m)) {
			$sections[] = $cur;
			$cur = array('name' => $m[1], 'type' => null, 'lines' => array());
			continue;
		}
		$trimmed = trim($line);
		if ($trimmed !== '' && $trimmed[0] !== ';' && strpos($trimmed, '=') !== false) {
			$eq = strpos($trimmed, '=');
			$key = trim(substr($trimmed, 0, $eq));
			$val = substr($trimmed, $eq + 1); // keep value as-is (may have leading space)
			$val = ltrim($val);
			$entry = array('kind' => 'kv', 'key' => $key, 'value' => $val, 'raw' => $line);
			$cur['lines'][] = $entry;
			if (strcasecmp($key, 'type') === 0) {
				$cur['type'] = $val;
			}
		} else {
			$cur['lines'][] = array('kind' => 'raw', 'raw' => $line);
		}
	}
	$sections[] = $cur;

	// Drop a leading empty preamble if it has no content
	if (count($sections) > 0 && $sections[0]['name'] === '') {
		$empty = true;
		foreach ($sections[0]['lines'] as $l) {
			if ($l['kind'] === 'kv' || ($l['kind'] === 'raw' && trim($l['raw']) !== '')) {
				$empty = false;
				break;
			}
		}
		if ($empty) {
			array_shift($sections);
		}
	}

	return $sections;
}

/**
 * @param  array $sections
 * @param  array $needle
 * @return int|null
 */
private function findPjsipSectionIndex($sections, $needle) {

	if ($needle['type'] !== null && $needle['type'] !== '') {
		foreach ($sections as $i => $sec) {
			if ($sec['type'] !== null && strcasecmp($sec['type'], $needle['type']) === 0) {
				return $i;
			}
		}
		return null;
	}
	// No type in overlay: match by section name only (last resort)
	foreach ($sections as $i => $sec) {
		if ($sec['name'] !== '' && strcasecmp($sec['name'], $needle['name']) === 0) {
			return $i;
		}
	}
	return null;
}

/**
 * @param  array $sections
 * @return string
 */
private function emitPjsipConfSections($sections) {

	$parts = array();
	foreach ($sections as $sec) {
		$chunk = array();
		if ($sec['name'] !== '') {
			$chunk[] = '[' . $sec['name'] . ']';
		}
		foreach ($sec['lines'] as $line) {
			if ($line['kind'] === 'kv') {
				$chunk[] = $line['key'] . '=' . $line['value'];
			} else {
				$chunk[] = $line['raw'];
			}
		}
		$parts[] = implode("\n", $chunk);
	}
	return implode("\n", $parts);
}

/**
 * Write thin per-phone overlay (not a full tmpl clone).
 * @param  string $key phone shortuid
 * @param  string $data overlay fragment
 * @return bool
 */
public function setPjsipPhoneInstance($key,$data) {

	$this->createPjsipPhoneInstance($key);
	$targetFile = ASTENDPOINTS . '/' . $key . '_' . PJSIP_PHONE_OVERLAY;
	if ($data === null) {
		$data = '';
	}

	$fh = fopen($targetFile, 'w') or die("Could not open file $targetFile!");
	if (fwrite($fh, $data) === false) {
		die("Could not write to file $targetFile !");
	}
	fclose($fh);
	$this->request_syscmd("/bin/chown asterisk:asterisk $targetFile >/dev/null 2>&1");
	$this->request_syscmd("/bin/chmod 664 $targetFile >/dev/null 2>&1");
	return True;
}

/**
 * Move phone overlay (and legacy frozen conf if present).
 * @param  string $key
 * @param  string $newkey
 * @return mixed
 */
public function movePjsipPhoneInstance($key,$newkey) {

	$rc = False;
	$overlayFile = ASTENDPOINTS . '/' . $key . '_' . PJSIP_PHONE_OVERLAY;
	$overlayNew = ASTENDPOINTS . '/' . $newkey . '_' . PJSIP_PHONE_OVERLAY;
	if (file_exists($overlayFile)) {
		$rc = $this->request_syscmd("/bin/mv $overlayFile $overlayNew >/dev/null 2>&1");
	}
	$legacyFile = ASTENDPOINTS . '/' . $key . '_' . PJSIP_PHONE;
	$legacyNew = ASTENDPOINTS . '/' . $newkey . '_' . PJSIP_PHONE;
	if (file_exists($legacyFile)) {
		$rc = $this->request_syscmd("/bin/mv $legacyFile $legacyNew >/dev/null 2>&1");
	}
	return $rc;
}

/**
 * Delete phone overlay (and legacy frozen conf if present).
 * @param  string $key phone shortuid
 * @return mixed
 */
public function deletePjsipPhoneInstance($key) {

	$rc = False;
	$overlayFile = ASTENDPOINTS . '/' . $key . '_' . PJSIP_PHONE_OVERLAY;
	if (file_exists($overlayFile)) {
		$rc = $this->request_syscmd("/bin/rm $overlayFile >/dev/null 2>&1");
	}
	$legacyFile = ASTENDPOINTS . '/' . $key . '_' . PJSIP_PHONE;
	if (file_exists($legacyFile)) {
		$rc = $this->request_syscmd("/bin/rm $legacyFile >/dev/null 2>&1");
	}
	return $rc;
} 

/**
 * Ensure endpoints dir for WebRTC overlays (stock tmpl is never copied).
 * @param  string $key phone shortuid
 * @return bool
 */
public function createPjsipWebrtcInstance($key) {

	if (!is_dir(ASTENDPOINTS)) {
		$this->request_syscmd("/bin/mkdir -p " . ASTENDPOINTS . " >/dev/null 2>&1");
		$this->request_syscmd("/bin/chown asterisk:asterisk " . ASTENDPOINTS . " >/dev/null 2>&1");
	}
	return true;
}

/**
 * Stock pjsip_webrtc.tmpl plus optional thin overlay (pre-xlate).
 * Same merge rules as phones. Home of record: $dbOverlay (ipphone.pjsip_overlay).
 * File under endpoints/ is fallback when DB overlay is empty. Legacy {key}_webrtc.conf ignored.
 * @param  string      $key phone shortuid
 * @param  string|null $dbOverlay thin overlay text from extension row
 * @return string|false
 */
public function getPjsipWebrtcInstance($key, $dbOverlay = null) {

	if (!file_exists(PJSIP_WEBRTC_TEMPLATE)) {
		return false;
	}
	$buff = file_get_contents(PJSIP_WEBRTC_TEMPLATE);
	if ($buff === false) {
		return false;
	}

	$overlay = null;
	if ($dbOverlay !== null && trim((string) $dbOverlay) !== '') {
		$overlay = (string) $dbOverlay;
	} else {
		$overlayFile = ASTENDPOINTS . '/' . $key . '_' . PJSIP_WEBRTC_OVERLAY;
		if (file_exists($overlayFile) && filesize($overlayFile) > 0) {
			$fileOverlay = file_get_contents($overlayFile);
			if ($fileOverlay !== false && trim($fileOverlay) !== '') {
				$overlay = $fileOverlay;
			}
		}
	}
	if ($overlay !== null) {
		$buff = $this->mergePjsipPhoneOverlay($buff, $overlay);
	}
	return $buff;
}

/**
 * Write thin per-WebRTC overlay (not a full tmpl clone).
 * @param  string $key phone shortuid
 * @param  string $data overlay fragment
 * @return bool
 */
public function setPjsipWebrtcInstance($key,$data) {

	$this->createPjsipWebrtcInstance($key);
	$targetFile = ASTENDPOINTS . '/' . $key . '_' . PJSIP_WEBRTC_OVERLAY;
	if ($data === null) {
		$data = '';
	}

	$fh = fopen($targetFile, 'w') or die("Could not open file $targetFile!");
	if (fwrite($fh, $data) === false) {
		die("Could not write to file $targetFile !");
	}
	fclose($fh);
	$this->request_syscmd("/bin/chown asterisk:asterisk $targetFile >/dev/null 2>&1");
	$this->request_syscmd("/bin/chmod 664 $targetFile >/dev/null 2>&1");
	return True;
}

/**
 * Move WebRTC overlay (and legacy frozen conf if present).
 * @param  string $key
 * @param  string $newkey
 * @return mixed
 */
public function movePjsipWebrtcInstance($key,$newkey) {

	$rc = False;
	$overlayFile = ASTENDPOINTS . '/' . $key . '_' . PJSIP_WEBRTC_OVERLAY;
	$overlayNew = ASTENDPOINTS . '/' . $newkey . '_' . PJSIP_WEBRTC_OVERLAY;
	if (file_exists($overlayFile)) {
		$rc = $this->request_syscmd("/bin/mv $overlayFile $overlayNew >/dev/null 2>&1");
	}
	$legacyFile = ASTENDPOINTS . '/' . $key . '_' . PJSIP_WEBRTC;
	$legacyNew = ASTENDPOINTS . '/' . $newkey . '_' . PJSIP_WEBRTC;
	if (file_exists($legacyFile)) {
		$rc = $this->request_syscmd("/bin/mv $legacyFile $legacyNew >/dev/null 2>&1");
	}
	return $rc;
}

/**
 * Delete WebRTC overlay (and legacy frozen conf if present).
 * @param  string $key phone shortuid
 * @return mixed
 */
public function deletePjsipWebrtcInstance($key) {

	$rc = False;
	$overlayFile = ASTENDPOINTS . '/' . $key . '_' . PJSIP_WEBRTC_OVERLAY;
	if (file_exists($overlayFile)) {
		$rc = $this->request_syscmd("/bin/rm $overlayFile >/dev/null 2>&1");
	}
	$legacyFile = ASTENDPOINTS . '/' . $key . '_' . PJSIP_WEBRTC;
	if (file_exists($legacyFile)) {
		$rc = $this->request_syscmd("/bin/rm $legacyFile >/dev/null 2>&1");
	}
	return $rc;
}

/**
 *  Queue functions CRUD
 */

/**
 * Ensure queues dir for overlays (stock tmpl is never copied).
 * @param  string $key queue pkey
 * @return bool
 */
public function createQInstance($key) {

	if (!is_dir(ASTQUEUES)) {
		$this->request_syscmd("/bin/mkdir -p " . ASTQUEUES . " >/dev/null 2>&1");
		$this->request_syscmd("/bin/chown asterisk:asterisk " . ASTQUEUES . " >/dev/null 2>&1");
	}
	return true;
}

/**
 * Stock queue.tmpl plus optional thin overlay (pre-xlate).
 * Home of record: $dbOverlay (queue.queue_overlay). File under queues/ is
 * fallback when DB empty. Legacy {pkey}_queue.conf ignored. Body is flat KV
 * (GenClass prepends [shortuid]).
 * @param  string      $key queue pkey
 * @param  string|null $dbOverlay
 * @return string|false
 */
public function getQInstance($key, $dbOverlay = null) {

	$this->createQInstance($key);
	if (!file_exists(QUEUE_TEMPLATE)) {
		return false;
	}
	$buff = file_get_contents(QUEUE_TEMPLATE);
	if ($buff === false) {
		return false;
	}

	$overlay = null;
	if ($dbOverlay !== null && trim((string) $dbOverlay) !== '') {
		$overlay = (string) $dbOverlay;
	} else {
		$overlayFile = ASTQUEUES . '/' . $key . '_' . QUEUE_OVERLAY;
		if (file_exists($overlayFile) && filesize($overlayFile) > 0) {
			$fileOverlay = file_get_contents($overlayFile);
			if ($fileOverlay !== false && trim($fileOverlay) !== '') {
				$overlay = $fileOverlay;
			}
		}
	}
	if ($overlay !== null) {
		$buff = $this->mergeFlatConfOverlay($buff, $overlay);
	}
	return $buff;
}

/**
 * Write thin per-queue overlay.
 * @param  string $key
 * @param  string $data
 * @return bool
 */
public function setQInstance($key, $data) {

	$this->createQInstance($key);
	$targetFile = ASTQUEUES . '/' . $key . '_' . QUEUE_OVERLAY;
	$fh = fopen($targetFile, 'w') or die("Could not open file $targetFile!");
	fwrite($fh, $data) or die("Could not write to file $targetFile !");
	fclose($fh);
	$this->request_syscmd("/bin/chown asterisk:asterisk $targetFile >/dev/null 2>&1");
	$this->request_syscmd("/bin/chmod 664 $targetFile >/dev/null 2>&1");
	return true;
}

/**
 * Delete queue overlay (and legacy freeze if present).
 * @param  string $key
 * @return mixed
 */
public function deleteQInstance($key) {

	$rc = false;
	$overlayFile = ASTQUEUES . '/' . $key . '_' . QUEUE_OVERLAY;
	if (file_exists($overlayFile)) {
		$rc = $this->request_syscmd("/bin/rm $overlayFile >/dev/null 2>&1");
	}
	$legacyFile = ASTQUEUES . '/' . $key . '_' . QUEUE;
	if (file_exists($legacyFile)) {
		$rc = $this->request_syscmd("/bin/rm $legacyFile >/dev/null 2>&1");
	}
	return $rc;
}

/**
 *  Park functions CRUD
 */

/**
 * Ensure callparks dir for overlays (stock tmpl is never copied).
 * @param  string $key cluster shortuid
 * @return bool
 */
public function createParkInstance($key) {

	if (!is_dir(ASTPARKS)) {
		$this->request_syscmd("/bin/mkdir -p " . ASTPARKS . " >/dev/null 2>&1");
		$this->request_syscmd("/bin/chown asterisk:asterisk " . ASTPARKS . " >/dev/null 2>&1");
	}
	return true;
}

/**
 * Stock parking_lot.tmpl plus optional thin overlay (pre-xlate).
 * Home of record: $dbOverlay (cluster.park_overlay). File under callparks/ is
 * fallback when DB empty. Legacy {shortuid}_parking.conf ignored.
 * @param  string      $key cluster shortuid
 * @param  string|null $dbOverlay
 * @return string|false
 */
public function getParkInstance($key, $dbOverlay = null) {

	$this->createParkInstance($key);
	if (!file_exists(PARK_TEMPLATE)) {
		return false;
	}
	$buff = file_get_contents(PARK_TEMPLATE);
	if ($buff === false) {
		return false;
	}

	$overlay = null;
	if ($dbOverlay !== null && trim((string) $dbOverlay) !== '') {
		$overlay = (string) $dbOverlay;
	} else {
		$overlayFile = ASTPARKS . '/' . $key . '_' . PARK_OVERLAY;
		if (file_exists($overlayFile) && filesize($overlayFile) > 0) {
			$fileOverlay = file_get_contents($overlayFile);
			if ($fileOverlay !== false && trim($fileOverlay) !== '') {
				$overlay = $fileOverlay;
			}
		}
	}
	if ($overlay !== null) {
		$buff = $this->mergePjsipPhoneOverlay($buff, $overlay);
	}
	return $buff;
}

/**
 * Write thin per-park overlay.
 * @param  string $key cluster shortuid
 * @param  string $data
 * @return bool
 */
public function setParkInstance($key, $data) {

	$this->createParkInstance($key);
	$targetFile = ASTPARKS . '/' . $key . '_' . PARK_OVERLAY;
	$fh = fopen($targetFile, 'w') or die("Could not open file $targetFile!");
	fwrite($fh, $data) or die("Could not write to file $targetFile !");
	fclose($fh);
	$this->request_syscmd("/bin/chown asterisk:asterisk $targetFile >/dev/null 2>&1");
	$this->request_syscmd("/bin/chmod 664 $targetFile >/dev/null 2>&1");
	return true;
}

/**
 * Delete park overlay (and legacy freeze if present).
 * @param  string $key cluster shortuid
 * @return mixed
 */
public function deleteParkInstance($key) {

	$rc = false;
	$overlayFile = ASTPARKS . '/' . $key . '_' . PARK_OVERLAY;
	if (file_exists($overlayFile)) {
		$rc = $this->request_syscmd("/bin/rm $overlayFile >/dev/null 2>&1");
	}
	$legacyFile = ASTPARKS . '/' . $key . '_' . PARK;
	if (file_exists($legacyFile)) {
		$rc = $this->request_syscmd("/bin/rm $legacyFile >/dev/null 2>&1");
	}
	return $rc;
}



/**
 *  IAX CRUD
 */

/**
 * Copy file template to named IAX file
 * @param  $key
 * @return bool  
 */
public function createIaxInstance($tuple) {

	switch ($tuple['iaxreg']) {
		case "SND":
			$templateFile = IAX_TRUNK_SNDREG_TEMPLATE;
			break;
		case "RCV":
			$templateFile = IAX_TRUNK_RCVREG_TEMPLATE;
			break;									
		default: 
			$templateFile = IAX_TRUNK_TRUSTED_TEMPLATE;					
	}
	$targetFile = ASTIAX . '/' . $tuple['pkey'] . '_' . IAX_TRUNK;

	if (!file_exists($targetFile) || 0 == filesize( $targetFile )) {
		$rc = $this->request_syscmd ("/bin/cp $templateFile $targetFile >/dev/null 2>&1");		
		$rc = $this->request_syscmd ("/bin/chown asterisk:asterisk $targetFile >/dev/null 2>&1");
		$rc = $this->request_syscmd ("/bin/chmod 664 $targetFile >/dev/null 2>&1");
		return true;
	}
	return false;
}

/**
 * get named IAX template
 * @param  array $tuple IAX row
 * @return bool  
 */
public function getIaxInstance($tuple) {

	$targetFile = ASTIAX . '/' . $tuple['pkey'] . '_' . IAX_TRUNK;
	if (!file_exists($targetFile)) {		
		$this->createIaxInstance($tuple);
	}
	if (file_exists($targetFile)) {
		return file_get_contents($targetFile);
	}
	return false;
} 

/**
 * set named IAX template
 * @param  array $tuple IAX row
 * @return bool  
 */
public function setIaxInstance($key,$data) {
	
	$targetFile = ASTIAX . '/' . $key . '_' . IAX_TRUNK;

	if (empty($data)) {		
		$this->createIaxInstance($key);
	}

	$fh = fopen($targetFile, 'w') or die("Could not open file $targetFile!");
	fwrite($fh,$data) or die("Could not write to file $targetFile !");
	fclose($fh);
	return True;	
} 

/**
 * delete named IAX template
 * @param  array $tuple Queue row
 * @return RC  
 */
public function deleteIaxInstance($key) {

	$targetFile = ASTIAX . '/' . $key . '_' . IAX_TRUNK;
	if (file_exists($targetFile)) {
		return $this->request_syscmd ("/bin/rm $targetFile >/dev/null 2>&1");
	}
	return False;	
}

/**
 * check/set the symlinks between asterisk and our config files 
 */
public function setLinks()
{
	$fileObjects = new RecursiveIteratorIterator(new RecursiveDirectoryIterator(ASTLOCALCONF));

	foreach($fileObjects as $file) 
	{
		echo "examining file " . $file->getFilename() . "\n";
		if ($file->isDir()) {
			continue;
		}

		$astFile =  ASTPATH . "/" . $file->getFilename();
		$localFile = ASTLOCALCONF . "/" . $file->getFilename();
		echo "local file is $localFile \n";
		echo "Ast file is $astFile \n";
		if (file_exists($astFile)) {
/**
 *  $file->islink() appears not to work so we use the older is_link function on the full path
 */
			if (is_link($astFile)) {
				echo "already linked $astFile \n";
				continue;
			}
			else {
				echo "move file $astFile \n";
				rename($astFile, $astFile ."_installed");
			}
		} 
		echo "link file $astFile \n";
		symlink($localFile, $astFile);

	}

	return(true);
}

public function checkXref($key,$cluster=false) {

/*
 * Legacy code to check for key clashes
 * find key clashes
 *	Checks a full key or a shortkey (no cluster ID prefix) with a cluster name qualifier
 *	MUST run on the OLD database structure when master_xref still exists
 */	
	$dbh = DB::getInstance();
	
	$sql = "SELECT * FROM master_xref where pkey = '$key'";
	if ($cluster) {
		$sql .= " AND cluster = '$cluster'";
	}

	$res = $dbh->query($sql)->fetch(PDO::FETCH_ASSOC);
	if (empty($res)) {
		return false;
	}	
	$foundKey = $res['pkey'];
	$relation = $res['relation'];

	switch ($relation) {
		case "ipphone":
			$relation = "Extension";
			break;
		case "speed";
			$relation = "Ring Group";
			break;
		case "ivrmenu":
			$relation = "IVR";
			break;
		case "meetme":
			$relation = "Conference";
			break;			
	}
	return $relation;
	
}

public function getTable($table, $sql='',$filter=true,$default=false,$order='pkey',$cast=false) {
/*
 * general table getter - it is used to filter the rows a panel "sees" based upon the
 * user who is making the request. - In general a user is filtered according to the
 * cluster(tenant) which owns it.
 */ 
	$dbh = DB::getInstance();
		
	if ( $sql == '' ) {
		$sql = "SELECT * from $table";
	}

// only do next if we're on-line	
	if (!empty($_SESSION)) {			
		if ($_SESSION['user']['pkey'] != 'admin' && $filter) {	
			$usql = $dbh->prepare("SELECT cluster,selection FROM user where pkey = ?");
			$usql->execute(array($_SESSION['user']['pkey']));
			$res = $usql->fetch();		
			if 	(array_key_exists('cluster',$res) && $res['selection'] != 'all' ) {
				$sql .= " WHERE cluster = '" . $res['cluster'] . "'";
				if ($default) {
					$sql .= " OR cluster='default'";
				}
			}			
		}
	}
	if ($cast) {
		$sql .= " ORDER BY CAST(" . $order . " AS NUMBER)";
	}
	else {
		$sql .= " ORDER BY " . $order . " COLLATE NOCASE ASC";
	}
	$this->logit("getTable; I'm running sql $sql",3 );
	$res = $dbh->query($sql);    
	$return = $res->fetchAll(); 
	return $return;
}

public function createTuple($tab,$rec,$check=true,$clusterid=false) {
/*
 * general tuple create - takes a table name and a partial array and creates a row 
 * 
 */ 
	$dbh = DB::getInstance();

/*
 * Check if the row already exists 
 */
	if ($check) {
		if ($clusterid) {
			$sql = $dbh->prepare("SELECT pkey FROM $tab WHERE pkey = ? AND cluster = ?");
			$sql->execute(array($rec['pkey'],$rec['cluster']));
		}
		else {
			$sql = $dbh->prepare("SELECT pkey FROM $tab WHERE pkey = ?");
			$sql->execute(array($rec['pkey']));
		}
		$res = $sql->fetch();		
		if ( isset($res['pkey']) ) { 
			return "400 Row ( " . $rec['pkey'] . " ) already exists!";
		}
	}

/*
 * get a default row for this table
 * careful with this function call - its a call to whatever is in the variable $table not to a 
 * function called "table".
 */ 

	$outbuf = array();
/*
 * add the given array to the default array
 */ 
	foreach ($rec as $key=>$value ) {
		$outbuf[$key] = $value;
	}

/*
 * build the sql arguments
 */
	$varg =  array();	//   array of the actual values
	$vnarg = null;		// 	 varable name arg (list of the comma separated variable names)
	$qarg = null;		// 	 varable name arg (list of comma separated query placeholders for prepare)
	
	foreach ($outbuf as $key=>$value) {
		if (!strlen($value) == 0) {
			array_push($varg, $value);
			$qarg .= "?,";
			$vnarg .= $key . ',';
		}
	}

/*
 * remove trailing commas
 */ 
	$vnarg = substr($vnarg, 0, -1);
	$qarg = substr($qarg, 0, -1);
/*
 * ready the insert
 */
	$sql = $dbh->prepare("INSERT INTO $tab ($vnarg) VALUES ($qarg)");
/*
 * do it
 */ 
	try {
		$sql->execute($varg);
	} 
	catch (PDOException $e) {
		echo "\n" . $e->getMessage() . "\n";
    	return $e->getMessage();	
    } 
	
	$this->commitOn();
	$this->logit("I'm creating a new $tab with $vnarg and $varg[0]",5 );
	return 'OK';
}

public function setTuple($tab,$rec,$modpkey=false) {

/*
 * general tuple setter - takes a table name and a partial array and updates a row 
 */
	$dbh = DB::getInstance();
/*
 *  check for pkey
 */ 
	if (!array_key_exists('pkey',$rec)) {
		return "Update failed - no pkey given!";
	}
	$pkey = $rec['pkey'];

/*
 * Check the row exists 
 */
	$sql = $dbh->prepare("SELECT pkey FROM $tab WHERE pkey = ?");
	$sql->execute(array($rec['pkey']));
	$res = $sql->fetch();	
	if ( ! isset($res['pkey']) ) { 
		return "Row (" . $pkey . " ) doesn't exist!";
	}  
/*
 * build the sql arguments
 */
	$varg =  array();	//   array of the actual values
	$vnarg = null;		// 	 varable name arg (list of the comma separated variable names)
	
	foreach ($rec as $key=>$value) {
// ignore key field unless explicitly changed 
		if ($key == 'pkey') {
			if ($modpkey != false) {
				$vnarg .= $key . "=?,";
				array_push($varg,$modpkey);  
			}				
		}
		else {
			$vnarg .= $key . "=?," ;
			array_push($varg,$value); 	
		}			
	}
/*
 * remove trailing commas
 */ 
	$vnarg = substr($vnarg, 0, -1);
/*
 * ready the update
 */
	array_push($varg,$pkey);
	$sql = $dbh->prepare("UPDATE $tab SET $vnarg WHERE pkey=?");
/*
 * do it
 */
	try {
		$sql->execute($varg);
	} 
	catch (PDOException $e) {
    	return $e->getMessage();	
    }   

	$this->commitOn();
	$this->logit("I'm updating $tab $vnarg with ...",3 );
	foreach ($varg as $v) {
		$this->logit("$v ...",3 );
	}
	return 'OK';
}	

public function setTupleById($tab,$rec) {

/*
 * general tuple setter - takes a table name and a partial array and updates a row 
 */
	$dbh = DB::getInstance();
/*
 *  check for pkey
 */ 
	if (!array_key_exists('id',$rec)) {
		return "Update failed - no id given!";
	}
	$id = $rec['id'];

/*
 * Check the row exists 
 */
	$sql = $dbh->prepare("SELECT id FROM $tab WHERE id = ?");
	$sql->execute(array($id));
	$res = $sql->fetch();	
	if ( ! isset($res['id']) ) { 
		return "Row (" . $id . " ) doesn't exist!";
	}  
/*
 * build the sql arguments
 */
	$varg =  array();	//   array of the actual values
	$vnarg = null;		// 	 varable name arg (list of the comma separated variable names)
	
	foreach ($rec as $key=>$value) {
// ignore id field  
		if ($key == 'id') {
			continue;			
		}
		else {
			$vnarg .= $key . "=?," ;
			array_push($varg,$value); 	
		}			
	}
/*
 * remove trailing commas
 */ 
	$vnarg = substr($vnarg, 0, -1);
/*
 * ready the update
 */
	array_push($varg,$id);
	$sql = $dbh->prepare("UPDATE $tab SET $vnarg WHERE id=?");
/*
 * do it
 */
	try {
		$sql->execute($varg);
	} 
	catch (PDOException $e) {
    	return $e->getMessage();	
    }   
	$this->commitOn();
	$this->logit("I'm updating $tab",3 );
	return 'OK';
}	

/**
 * logIt
 *
 * @param  mixed $someText - message to log
 * @param  mixed $userloglevel - message log level - if sys LOGLEVEL is higher than $userloglevel - send it!
 * @return void
 */
public function logIt($someText, $userloglevel=0) {
	$dbh = DB::getInstance();
	$res = $dbh->query("SELECT loglevel FROM globals LIMIT 1")->fetch(PDO::FETCH_ASSOC);
	$dbloglevel = isset($res['loglevel']) ? $res['loglevel'] : 0;
	if ($userloglevel <= $dbloglevel) {
		syslog(LOG_WARNING, $_SERVER['PHP_SELF'] . ' ' . $someText . "\n");	
	}
}

/**
 * resetPassword
 *
 * @param [type] $user
 * @return void
 * 
 * NOT USED IN THIS RELEASE
 */
public function resetPassword ($user) {

	$dbh = DB::getInstance();

	$res = $dbh->query("SELECT userotp FROM globals LIMIT 1")->fetch(PDO::FETCH_ASSOC);
    $newpass = isset($res['userotp']) ? $res['userotp'] : ''; 
    $this->logit("Reset password to $newpass for $user", 5 );
	$salt = dechex(mt_rand(0, 2147483647)) . dechex(mt_rand(0, 2147483647));
	$password = hash('sha256', $newpass . $salt); 
	for($round = 0; $round < 65536; $round++) {
		$password = hash('sha256', $password . $salt); 
	}
	$tuple['pkey'] = $user; 
	$tuple['password'] = $password;
	$tuple['salt'] = $salt;
	$ret = $this->setTuple('user',$tuple);

}
/**
 * getDirectDial
 *
 * @param string $route
 * @param string $routename
 * @param integer $routeclass
 * @return integer dialable number (or false if not found)
 */
public function getDirectDial($route,$routeclass,&$dialstring,&$msg,&$rc) {
	$dbh = DB::getInstance();
	$table = null;
	$dialstring = null;
	switch ($routeclass) {
		case 1: 
			// nothing to do, already dialable
			$dialstring = $route;
			$msg =  "202 Appl Row $route is already dialable";
			$rc = 202;
			return true;
		case 2:
			//IVR
			$table = "ivrmenu";
			$sql = $dbh->prepare("SELECT pkey FROM ivrmenu WHERE name = ?");
			$sql->execute(array($route));
			$res = $sql->fetch();	
			if ( ! isset($res['pkey']) ) { 
				$msg =  "401 IVR Row $route doesn't exist!";
				$rc = 401;
				return false;
			}  
			$rc = 200;
			$dialstring = $res['pkey'];
			return true;
			break;
		case 4:
			//Queue
			$table = "queue";  
			$sql = $dbh->prepare("SELECT pkey FROM queue WHERE name = ?");
			$sql->execute(array($route));
			$res = $sql->fetch();	
			if ( ! isset($res['pkey']) ) { 
				$msg =  "401 Queue Row $route doesn't exist!";
				$rc = 401;
				return false;
			} 
			$dialstring = $res['pkey'];
			$rc = 200;
			return true; 			
			break;
		case 10:
			//custom app 
			$table = "appl";
			$table = "queue";  
			$sql = $dbh->prepare("SELECT pkey FROM appl WHERE name = ?");
			$sql->execute(array($route));
			$res = $sql->fetch();	
			if ( ! isset($res['pkey']) ) { 
				$msg =  "401 Appl Row $route doesn't exist!";
				$rc = 401;
				return false;
			}
			$dialstring = $res['pkey'];
			$rc = 200;
			return true;  						
			break;
		case 20:
			//retrieve voicemail - set target to *51* 
			$dialstring = "*51*";
			return true;
		case 100:
			//Operator
			$dialstring = 100;
			return true;
		case 101:
			//Hangup
			$dialstring = 101;
			return true;

		case 0: 
		// nothing to do - should never happen

		case 3:
			//Never used
		case 5:
			//DISA - not implemented - insecure
		case 6:
			//CALLBACK - old feature not used
		case 7:
			//Never used
		case 8:
			//sibling - not used by IVR
		case 9:
			//trunk name - not used by IVR
		case 11:
			//trunk group - not used by IVR
		case 21:
			//leave voicemail - not used by IVR
		default:
		$dialstring = "None";
			$msg =  "\n502 returned RC $routeclass for $route not implemented - set to 'None'\n\n";
			$rc = 502;
			return false;
	}
}

  
}
