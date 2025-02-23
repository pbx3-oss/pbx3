<?php
// +-----------------------------------------------------------------------+
// |  Copyright (c) KoKoKraft 2024
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
// | Author: KoKoKraft                                                      
// +-----------------------------------------------------------------------+
// 

/**
 *  Ignores And Drops production conversion 
 *  Used by the dumper 
 *  ignores set in $ignores array 
 *  drops set in the $drops array.   This allows the removal of columns
 *  which are no longer used.     
 */

 /**
 *  tables to ignore - mostly old deleted tables
 */

 $ignores = array (
	"Carrier",			
	"mfgmac",
	"vendorxref",
	"Device",
	"Device_atl",
	"Trunk",
	"IPphone_FKEY",
	"undolog",
	"tt_help_user",
	"vendorxref",
	"Device",
	"device_atl",
	"IPphone_FKEY",
	"netphone",
	"master_xref",
	"master_audit",
	"tt_help_core",
	"Panel",
	"PanelGroup",
	"PanelGroupPanel",
	"sysuser",
	"UserPanel",
	"User"
 );

/**
 * Deprecated Columns to drop
 */

 $drops = array (
		"Appl" => array (
			"desc"	
		),	
		"globals" => array (
			"AGENTSTART",
			"ACL",
			"ALERT",
			"ALLOWHASHXFER",
			"ASTDLIM",	
			"ATTEMPTRESTART",
			"BLINDBUSY",
			"BOUNCEALERT",			
			"CALLPARKING",
			"CALLRECORD1",
			"CAMPONQONOFF",
			"CAMPONQOPT",
			"CFWDEXTRNRULE",
			"CFWDPROGRESS",
			"CFWDANSWER",
			"COUNTRYCODE",
			"CLUSTER",
			"CLUSTERSTART",
			"CONFTYPE",
			"CONFSTART",
			"DESC",
			"DIGITS",
			"DYNAMICFEATURES",
			"EMAILALERT",
			"EXTBLKLST",
			"EXTLEN",
			"EXTLIM",
			"FAX",
			"FAXDETECT",
			"FOPPASS",
			"FQDNDROPBUFF",
			"FQDNHTTP",
			"FQDNTRUST",
			"HAAUTOFAILBACK",
			"HAENCRYPT",
			"HACLUSTERIP",
			"HAMODE",
			"HAPRINODE",
			"HASYNCH",
			"HAUSECLUSTER",
			"INTRINGDELAY",
			"IVRKEYWAIT",
			"IVRDIGITWAIT",
			"LACL",
			"LDAPANONBIND", 
			"LDAPBASE", 
			"LDAPHOST", 
			"LDAPOU", 
			"LDAPUSER", 
			"LDAPPASS", 
			"LDAPTLS", 
			"LEASEHDTIME",	
			"LKEY",
			"LOCALAREA",
			"LOCALDLEN",
			"LTERM",
			"MEETMEDIAL",
			"MISDNRUN",
			"MIXMONITOR",
			"MONITOROUT",
			"MONITORSTAGE",
			"MONITORTYPE",
			"NUMGROUPS",			
			"ONBOARDMENU",
			"OPRT",
			"PADMINPASS",
			"PLAYBEEP",
			"PLAYBUSY",
			"PLAYCONGESTED",
			"PLAYTRANSFER",
			"PROXY",
			"PUSERPASS",
			"PCICARDS",
			"RECAGE",
			"RECFINALDEST",
			"RECGRACE",
			"RESTART",
			"RINGDELAY",
			"RUNFOP",
			"SIPIAXSTART",
			"SIPMULTICAST",
			"SNO",
			"SPYPASS",
			"SUPEMAIL",
			"TFTP",
			"UNDO",
			"UNDONUM",
			"USERCREATE",
			"VCLFULL",
			"VDELAY",
			"VLIBS",
			"VXT",
			"VMAILAGE",
			"VOICEINSTR",
			"XMPP",
			"XMPPSERV",
			"ZTP"
			),
		"Carrier" => array (
				"desc",
				"md5encrypt",
				"provision",
				"register",
				"sipiaxpeer",
				"sipiaxuser",
				"pjsipreg",
				"pjsipuser",
				"zapcarfixed"	
			),
		"Cluster" => array (
			"callgroup",	
			"cfwd_extern_rule",
				"extlen",
				"ldapropwd",
				"max_in",
				"max_out",
				"monitor_type",
				"number_range_low",
				"number_range_high",
				"number_min_dial",
				"routeclassoverride",
				"startagent",
				"startconfroom",
				"startextension",
				"startivr",
				"startparks",
				"startqueue",
				"startringgroup",
			),
		"dateSeg" => array (
				"desc"	
			),
		"Device" => array (
				"imageurl",
				"noproxy",
				"tftpname",
				"zapdevfixed",
				"desc"
			),
		"Greeting" => array (
				"desc"	
			),
		"Holiday" => array (
				"desc",
				"routeclass"	
			),
		"inroutes" => array (
				"desc",
				"routeclassopen",
				"routeclassclosed"
			),				
		"IPphone" => array (
				"channel",
//				"desc",
				"dialstring",
				"externalip",
				"location",
				"newformat",
				"openfirewall",
				"sipiaxfriend",
				"twin"
				
			),
		"ivrmenu" => array (

				"routeclass0",
				"routeclass1",
				"routeclass10",
				"routeclass11",
				"routeclass2",
				"routeclass3",
				"routeclass4",
				"routeclass5",
				"routeclass6",
				"routeclass7",
				"routeclass8",
				"routeclass9",
				"timeoutrouteclass"

		),

		"Queue" => array (
			"conf",
			"directdial",
			"realname",
			"routeclassopen"	
		),
		"Route" => array (
			"desc"	
		),
		"trunks" => array (
			"routeclassopen",
			"routeclassclosed"
		)

	);