<?php
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

require_once __DIR__ . "/../config.php";

require_once NETHELPER;

$net = new nethelper();

$ip = $net->get_localIPV4();
$sleep = 0;

while (empty($ip)) {
	logit  ("waiting for network - retry in $sleep seconds");
	sleep ($sleep);
	unset ($net);
	$net = new nethelper();
	$ip = $net->get_localIPV4();
	if ($sleep < 30) {
		$sleep = $sleep + 5;
	}
}

$interface = $net->get_interfaceName();
$netaddress = $net->get_networkIPV4();
$cidr = $net->get_networkCIDR();
$msk = $net->get_netMask();
$ip = $net->get_localIPV4();
$staticIPV4 = $net->get_staticIPV4();

logit  ("Interface name on this node: $interface");
logit  ("IPV4: $ip");
logit  ("staticIPV4: $staticIPV4");
logit  ("Network address: $netaddress");
logit  ("netmask: $msk");
logit  ("CIDR: $cidr");

$f2b_target = '/etc/fail2ban/jail.conf';

if ($netaddress == '0.0.0.0' || empty($netaddress)) {
	logit ("!!!!!!!!! No IP returned from ip a !!!!!!!!!!  - check network cable");
}
else {
	if ($staticIPV4) {
		logit  ("Static Virt ip $staticIPV4");
		$net->set_staticIPV4(false,$staticIPV4);
	}
	# UFW solo SIP source (F10) — declarative LAN CIDR for ufw-apply-baseline.sh
	$lanCidr = $netaddress . '/' . $cidr;
	if (!is_dir('/etc/pbx3')) {
		@mkdir('/etc/pbx3', 0755, true);
	}
	if (@file_put_contents('/etc/pbx3/lan.cidr', $lanCidr . "\n") === false) {
		logit("could not write /etc/pbx3/lan.cidr");
	} else {
		logit("wrote /etc/pbx3/lan.cidr = $lanCidr");
	}
	# Legacy Shorewall params (no-op hosts may still have /etc/shorewall until Phase 4 purge)
	if ( file_exists( "/etc/shorewall") ) {
		`echo LAN=$netaddress/$cidr > /etc/shorewall/local.lan`;
		`echo IF1=$interface > /etc/shorewall/local.if1`;
	}
	
	if ( file_exists( "/etc/fail2ban/jail.d/pbx3-jails.conf" ) ) {
		`sed -i --follow-symlinks '/^ignoreip/c \ignoreip = 127.0.0.1 $netaddress\/$cidr 224.0.1.0\/24' /etc/fail2ban/jail.d/pbx3-jails.conf`;
		`fail2ban-client reload > /dev/null 2>&1`;
	} elseif ( file_exists( "/etc/fail2ban/jail.local" ) ) {
		`sed -i --follow-symlinks '/^ignoreip/c \ignoreip = 127.0.0.1 $netaddress\/$cidr 224.0.1.0\/24' /etc/fail2ban/jail.local`;
		`fail2ban-client reload > /dev/null 2>&1`;
	}
		
	if ( file_exists( "/etc/asterisk")) {
		# set correct Asterisk dateformat in logger.conf
		`sed -i 's/^;dateformat=%F %T /dateformat=%F %T/' /etc/asterisk/logger.conf`;
		`sed -i '/^messages/c \messages => security,notice,warning,error' /etc/asterisk/logger.conf`;
		# set localnet values for Asterisk
		`[ -e /etc/asterisk/CODENAME_sip_localnet.conf ] && /usr/bin/dos2unix /etc/asterisk/CODENAME_sip_localnet.conf`;
		`echo localnet=$netaddress/$msk >> /etc/asterisk/CODENAME_sip_localnet.conf`;
		`awk '!_[\$0]++'  /etc/asterisk/CODENAME_sip_localnet.conf > /tmp/localnet.tmp`;
		`mv /tmp/localnet.tmp /etc/asterisk/CODENAME_sip_localnet.conf`;
		`chown asterisk:asterisk /etc/asterisk/*`;
		`chmod 664 /etc/asterisk/*`;
		`asterisk -rx 'reload' > /dev/null`;
	}
	
/*
        Set an IP in /etc/issue for CPE systems
 */
	$sysrlse = trim(shell_exec("dpkg-query -W -f '\${version}\n' " . CODENAME . " 2>/dev/null") ?: '');
	$osrelease = trim (`lsb_release -d --short`);
	`echo "$osrelease/" . CODENAME . " $sysrlse running at $ip/$cidr" > /etc/issue`;
}

function logit ($someText) {
	syslog(LOG_WARNING, SYSPREFIX . " setip $someText");	
}

?>		
