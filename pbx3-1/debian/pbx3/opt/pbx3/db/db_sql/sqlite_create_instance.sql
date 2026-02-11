
BEGIN TRANSACTION;

/* SYSTEM TABLES - these are not backed up as part of a cluster backup */

/* system settings */
CREATE TABLE IF NOT EXISTS globals (
"pkey" TEXT PRIMARY KEY,
"abstimeout" INTEGER DEFAULT 14400,   -- default abstimeout 4 hours **MOVED**
"bindaddr" TEXT,                      -- Asterisk SIP bindaddr
"bindport" TEXT DEFAULT 5060,			-- SIP BINDPORT
"cosstart" TEXT DEFAULT 'ON',            -- COS onoff
"edomain" TEXT,                       -- external IP address of this server
"emergency" TEXT DEFAULT '999 112 911',  -- **MOVED**
"fqdn" TEXT,							-- FQDN - NEEDS TO MOVE
"fqdninspect" TEXT DEFAULT 'NO',		-- Require FQDN in SIP Ops Shorewall 4.6+ 
"fqdnprov" TEXT,						-- use FQDN in remote provisioning YES/NO
"language" TEXT DEFAULT 'en-gb',      -- used in extensions.conf 
"localip" TEXT,                       -- local ip address
"loglevel" INTEGER DEFAULT 0,				-- internal log level
"logopts" TEXT,
"logsipdispsize" INTEGER DEFAULT 2000,	-- number of SIP pcap lines to display
"logsipnumfiles" INTEGER DEFAULT 10,		-- number of SIP pcap spins to keep
"logsipfilesize" INTEGER DEFAULT 20000,	-- SIP pcap max filesize (bytes)
"maxin" INTEGER DEFAULT 30,              -- maximum inbound calls
"maxout" INTEGER DEFAULT 30,             -- maximum outbound calls
"mycommit" TEXT,                      -- commit outstanding
"natdefault" TEXT DEFAULT 'remote', 	-- V6 NAT defaiult local/remote
"natparams" TEXT DEFAULT 'force_rport,comedia', --V6 NAT default remote params
"operator" INTEGER DEFAULT 100,
"pwdlen" INTEGER DEFAULT 12,				-- password length deprecated
"recfiledlim" TEXT DEFAULT '_-_',     -- recordings filename delimiter
"reclimit" TEXT,                      -- recording max size
"recmount" TEXT,                   	-- Recording folder mount command
"recqdither" TEXT,                    -- dither (ms) on queuelog searches
"recqsearchlim" TEXT,                 -- search limit on queuelog
"sessiontimout" INTEGER DEFAULT 600,  -- sessiontimeout (10minutes)
"sendedomain" TEXT DEFAULT 'YES',  	-- Send public IP in SIP header YES/NO
"sipflood" TEXT DEFAULT 'NO',			-- detect SIP flood YES/NO
"sipdriver" TEXT DEFAULT 'PJSIP',		-- SIP backend now PJSIP
"sitename" TEXT,                      -- Common name for this site 
"staticipv4" TEXT DEFAULT NULL,		   -- Static IP to be started
"sysop" INTEGER DEFAULT 100,				-- system operator real extension
"syspass" INTEGER DEFAULT 4444,			-- password for sysops **MOVED** BUT....
"tlsport"	INTEGER DEFAULT 5061,		-- TLS port (default 5061)
"userotp" TEXT DEFAULT NULL,			   -- V6 default OTP.  Seeded by the generator
"vcl" TEXT DEFAULT '1',			      -- V5 cloud enabled (1/0)
"voipmax" INTEGER DEFAULT 30,			-- MAX outbound up calls 
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

