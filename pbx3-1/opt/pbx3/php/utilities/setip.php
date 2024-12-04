<?php
// +-----------------------------------------------------------------------+
// |  Copyright (c) KoKoKraft 2024                                  |
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
// | Author: KoKo                                                           |
// +-----------------------------------------------------------------------+
//


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
	if ( file_exists( "/etc/shorewall") ) {
		`echo LAN=$netaddress/$cidr > /etc/shorewall/local.lan`;
		`echo IF1=$interface > /etc/shorewall/local.if1`;
	}
	
	if ( file_exists( "/etc/fail2ban/jail.local")) {	
		`sed -i --follow-symlinks '/^ignoreip/c \ignoreip = 127.0.0.1 $netaddress\/$cidr 224.0.1.0\/24' /etc/fail2ban/jail.local`;
		`fail2ban-server reload > /dev/null`;
	}
		
	if ( file_exists( "/etc/asterisk")) {
		# set correct Asterisk dateformat in logger.conf
		`sed -i 's/^;dateformat=%F %T /dateformat=%F %T/' /etc/asterisk/logger.conf`;
		`sed -i '/^messages/c \messages => security,notice,warning,error' /etc/asterisk/logger.conf`;
		# set localnet values for Asterisk
		`[ -e /etc/asterisk/sark_sip_localnet.conf ] && /usr/bin/dos2unix /etc/asterisk/sark_sip_localnet.conf`;
		`echo localnet=$netaddress/$msk >> /etc/asterisk/sark_sip_localnet.conf`;
		`awk '!_[\$0]++'  /etc/asterisk/sark_sip_localnet.conf > /tmp/localnet.tmp`;
		`mv /tmp/localnet.tmp /etc/asterisk/sark_sip_localnet.conf`;
		`chown asterisk:asterisk /etc/asterisk/*`;
		`chmod 664 /etc/asterisk/*`;
		`asterisk -rx 'reload' > /dev/null`;
	}
	
/*
        Set an IP in /etc/issue for CPE systems
 */
	$sysrlse = trim(system("dpkg-query -W -f '\${version}\n' " . SYSNAME));
	$osrelease = trim (`lsb_release -d --short`);
	`echo "$osrelease/" . SYSNAME . " $sysrlse running at $ip/$cidr" > /etc/issue`;
}

function logit ($someText) {
	syslog(LOG_WARNING, SYSNAME . " setip $someText");	
}

?>		
