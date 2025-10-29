
BEGIN TRANSACTION;

/* SYSTEM TABLES - these are not backed up as part of a cluster backup */

/* system settings */
CREATE TABLE IF NOT EXISTS globals (
"pkey" TEXT PRIMARY KEY,
"ABSTIMEOUT" INTEGER DEFAULT 14400,   -- default abstimeout 4 hours **MOVED**
"BINDADDR" TEXT,                      -- Asterisk SIP bindaddr
"BINDPORT" TEXT DEFAULT 5060,			-- SIP BINDPORT
"COSSTART" TEXT DEFAULT 'ON',            -- COS onoff
"EDOMAIN" TEXT,                       -- external IP address of this server
"EMERGENCY" TEXT DEFAULT '999 112 911',  -- **MOVED**
"FQDN" TEXT,							-- FQDN - NEEDS TO MOVE
"FQDNINSPECT" TEXT DEFAULT 'NO',		-- Require FQDN in SIP Ops Shorewall 4.6+ 
"FQDNPROV" TEXT,						-- use FQDN in remote provisioning YES/NO
"LANGUAGE" TEXT DEFAULT 'en-gb',      -- used in extensions.conf 
"LOCALIP" TEXT,                       -- local ip address
"LOGLEVEL" INTEGER DEFAULT 0,				-- internal log level
"LOGOPTS" TEXT,
"LOGSIPDISPSIZE" INTEGER DEFAULT 2000,	-- number of SIP pcap lines to display
"LOGSIPNUMFILES" INTEGER DEFAULT 10,		-- number of SIP pcap spins to keep
"LOGSIPFILESIZE" INTEGER DEFAULT 20000,	-- SIP pcap max filesize (bytes)
"MAXIN" INTEGER DEFAULT 30,              -- maximum inbound calls
"MAXOUT" INTEGER DEFAULT 30,             -- maximum outbound calls
"MYCOMMIT" TEXT,                      -- commit outstanding
"NATDEFAULT" TEXT DEFAULT 'remote', 	-- V6 NAT defaiult local/remote
"NATPARAMS" TEXT DEFAULT 'force_rport,comedia', --V6 NAT default remote params
"OPERATOR" INTEGER DEFAULT 100,
"PWDLEN" INTEGER DEFAULT 12,				-- password length deprecated
"RECFILEDLIM" TEXT DEFAULT '_-_',     -- recordings filename delimiter
"RECLIMIT" TEXT,                      -- recording max size
"RECMOUNT" TEXT,                   	-- Recording folder mount command
"RECQDITHER" TEXT,                    -- dither (ms) on queuelog searches
"RECQSEARCHLIM" TEXT,                 -- search limit on queuelog
"SESSIONTIMOUT" INTEGER DEFAULT 600,  -- sessiontimeout (10minutes)
"SENDEDOMAIN" TEXT DEFAULT 'YES',  	-- Send public IP in SIP header YES/NO
"SIPFLOOD" TEXT DEFAULT 'NO',			-- detect SIP flood YES/NO
"SIPDRIVER" TEXT DEFAULT 'PJSIP',		-- SIP backend now PJSIP
"SITENAME" TEXT,                      -- Common name for this site 
"STATICIPV4" TEXT DEFAULT NULL,		   -- Static IP to be started
"SYSOP" INTEGER DEFAULT 100,				-- system operator real extension
"SYSPASS" INTEGER DEFAULT 4444,			-- password for sysops **MOVED** BUT....
"TLSPORT"	INTEGER DEFAULT 5061,		-- TLS port (default 5061)
"USEROTP" TEXT DEFAULT NULL,			   -- V6 default OTP.  Seeded by the generator
"VCL" TEXT DEFAULT '1',			      -- V5 cloud enabled (1/0)
"VOIPMAX" INTEGER DEFAULT 30,			-- MAX outbound up calls 
"z_created" datetime,
"z_updated" datetime,
"z_updater" TEXT DEFAULT 'system'
);

/* trunks/gateways */
CREATE TABLE IF NOT EXISTS trunks (
"id" TEXT,
"hrkey" TEXT UNIQUE,                  -- human readable key
"pkey" TEXT PRIMARY KEY,
"active" TEXT DEFAULT 'YES',	-- Active/inactive flag
"alertinfo" TEXT,				-- distinctive ring
"callback" TEXT,				-- denotes callback trunk
"callerid" TEXT,				-- high-order (weak) CLID
"callprogress" TEXT DEFAULT 'YES',		-- send progress tones on dial
"closeroute" TEXT,			-- closed inbound route
"cluster" TEXT,				-- cluster (Tenant) this trunk belongs to
"cname" TEXT,
"description" TEXT,			-- weak Asterisk username 
"devicerec" TEXT,			-- RECOPTS
"disa" TEXT,					-- DISA capable trunk
"disapass" TEXT,				-- DISA password
"host" TEXT,					-- Host IP address
"iaxreg" TEXT DEFAULT NULL,	-- Asterisk IAX registration (SND/RCV/NULL)		
"inprefix" TEXT,				-- prepend prefix on inbound
"match" TEXT,					-- trunk seize sequence
"moh" TEXT DEFAULT 'NO',	-- play moh instead of ring
"openroute" TEXT,			-- open inbound route
"password" TEXT,				-- far end password
"peername" TEXT,				-- strong Asterisk username
"pjsipreg" TEXT DEFAULT NULL,	-- Asterisk pjsip registration (SND/RCV/NULL)									
"privileged" TEXT,			-- privileged ingress 
"register" TEXT,				-- registration string
"swoclip" TEXT DEFAULT 'YES',	-- Switch On CLIP
"tag" TEXT,					-- Alpha tag
"technology" TEXT,           -- SIP/IAX2/DiD/CLiD/Class
"transform" TEXT,				-- Transformation mask
"transport" TEXT DEFAULT 'udp',
"trunkname" TEXT,				-- freeform trunkname
"username" TEXT,				-- far end username
"z_created" datetime,
"z_updated" datetime,
"z_updater" TEXT DEFAULT 'system'
);

/* messages table */
CREATE TABLE IF NOT EXISTS tt_help_core (
"pkey" TEXT PRIMARY KEY,
"displayname" TEXT,
"htext" TEXT,
  -- name is deprecated and will be dropped in a near release use cname instead
"name" TEXT,
"cname" TEXT,                            -- common name
"z_created" datetime,
"z_updated" datetime,
"z_updater" TEXT DEFAULT 'system'
);

COMMIT;

