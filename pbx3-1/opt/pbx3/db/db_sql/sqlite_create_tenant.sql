
BEGIN TRANSACTION;

/* agent */
CREATE TABLE IF NOT EXISTS agent (
    "id" TEXT PRIMARY KEY,                -- 27 char ksuid
    "shortuid" TEXT UNIQUE,                  -- human readable 8 char uid	
    "pkey" TEXT NOT NULL,
    "cluster" TEXT DEFAULT 'default',
    "conf" TEXT,
    "extlen" INTEGER,
    -- name is deprecated and will be dropped in a near release use cname instead
    "name" TEXT DEFAULT '*NEW agent*', 
    "cname" TEXT DEFAULT '*NEW agent*',
    "description" TEXT,
    "num" TEXT,
    "passwd" TEXT,				
    "queue1" TEXT DEFAULT 'None',
    "queue2" TEXT DEFAULT 'None',
    "queue3" TEXT DEFAULT 'None',
    "queue4" TEXT DEFAULT 'None',
    "queue5" TEXT DEFAULT 'None',
    "queue6" TEXT DEFAULT 'None',
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    UNIQUE("cluster", "pkey")
);
/* Custom app */
CREATE TABLE IF NOT EXISTS appl (
    "id" TEXT PRIMARY KEY,                -- 27 char ksuid 
    "shortuid" TEXT UNIQUE,                  -- human readable 8 char uid
    "pkey" TEXT NOT NULL,
    "active" TEXT DEFAULT 'YES',
    "cluster" TEXT DEFAULT 'default',
    "description" TEXT,
    "directdial" INTEGER DEFAULT 0,
    "extcode" TEXT,
    -- name is deprecated and will be dropped in a near release use cname instead
    "name" TEXT,
    "cname" TEXT,                            -- common name
    "span" TEXT DEFAULT 'Neither',
    "striptags" TEXT,
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system'
);
/* Class of service */
CREATE TABLE IF NOT EXISTS cos (
    "id" TEXT PRIMARY KEY,                -- 27 char ksuid
    "shortuid" TEXT UNIQUE,                  -- human readable 8 char uid
    "pkey" TEXT NOT NULL,
    "active" TEXT DEFAULT 'YES',
    "cluster" TEXT DEFAULT 'default',
    "cname" TEXT,
    "defaultclosed" TEXT DEFAULT 'NO',
    "defaultopen" TEXT  DEFAULT 'NO',
    "description" TEXT,
    "dialplan" TEXT DEFAULT NULL, 
    "orideclosed" TEXT DEFAULT 'NO', 
    "orideopen" TEXT DEFAULT 'NO',
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system'
);
/* Tenant/Cluster */
CREATE TABLE IF NOT EXISTS cluster (
    "id" TEXT PRIMARY KEY,                -- 27 char ksuid
    "shortuid" TEXT UNIQUE,                  -- human readable 8 char uid	
    "pkey" TEXT NOT NULL,
    "abstimeout" INTEGER DEFAULT 14400,
    "acl" BOOLEAN DEFAULT FALSE,
    "active" TEXT DEFAULT 'YES',
    "allow_hash_xfer"  TEXT DEFAULT 'enabled',                 -- Allow asterisk non-SIP xfer
    "blind_busy" TEXT,                     -- blind transfer busy bounce
    "bounce_alert" TEXT,
    "callrecord_1" TEXT DEFAULT 'None',      -- alertinfo string for blind transfer bounce
    "camp_on_q_onoff" TEXT,                  -- camp-on miniqueue enable
    "camp_on_q_opt" TEXT,                    -- camp-on miniqueue options
    "cfwdextern_rule" TEXT DEFAULT 'YES',    -- allow call forward to external numbers 
    "cfwd_progress"  TEXT DEFAULT 'enabled', -- turn on early-media,
    "cfwd_answer"   TEXT DEFAULT 'enabled',  -- take call off-hook before forward to external
    "clusterclid" TEXT,
    "chanmax" INTEGER DEFAULT 3,             -- maximum up channels for this tenant
    "cname" TEXT,                      -- common name
    "countrycode" INTEGER DEFAULT 44,			-- countrycode
    "dynamicfeatures" TEXT DEFAULT NULL,  -- Asterisk DYNAMIC_FEATURES string		
    "description" TEXT,       
    "devicerec" TEXT DEFAULT 'default',	   -- recording settings for this tenant
    "emailalert" TEXT,                       -- email alert address
    "emergency" TEXT DEFAULT '999 112 911',  -- emergency numbers which bypass COS
    "extblklist" TEXT,                        -- Needs work!!!!!!!!!
    "ext_lim" INTEGER DEFAULT 0,             -- extlim for this tenant
    "ext_len" INTEGER DEFAULT 3,             -- extlen for this cluster
    "fqdn" TEXT DEFAULT NULL,                --TRANSFORM!
    "fqdninspect" BOOLEAN DEFAULT FALSE,     --TRANSFORM!
    "include" TEXT,                          -- list of other tenants which may be short-dialled
    "int_ring_delay" INTEGER DEFAULT 20,		-- ring time before voicemail
    "ivr_key_wait" INTEGER DEFAULT 6,        -- how long to wait after keypress
    "ivr_digit_wait" INTEGER DEFAULT 6000,   -- how long to wait for another digit
    "language" TEXT DEFAULT 'en-gb',         -- used in extensions.conf 
    "ldapanonbind" TEXT DEFAULT 'YES',       -- anonymous bind YES/NO **MOVED**
    "ldapbase" TEXT DEFAULT 'dc=pbx3,dc=local',  -- LDAP base **MOVED**
    "ldaphost" TEXT DEFAULT '127.0.0.1',  -- LDAP host **MOVED**
    "ldapou" TEXT DEFAULT 'contacts',     -- LDAP OU **MOVED**
    "ldapuser" TEXT DEFAULT 'admin',		-- LDAP user **MOVED**
    "ldappass" TEXT DEFAULT 'pbx3admin',	-- LDAP password **MOVED**
    "ldaptls" TEXT DEFAULT 'off',              -- LDAP TLS mode(off/on)
    "localarea" TEXT,                        -- local area code
    "localdplan" TEXT,                       -- local number dialplan
    "lterm" INTEGER DEFAULT 0,			   -- late termination flag
    "leasedhdtime" INTEGER DEFAULT 43200,		-- Hot desk lease time
    "masteroclo" TEXT DEFAULT 'AUTO',
    "maxin" INTEGER DEFAULT 30,          -- max inbound calls allowed to be up
    "maxout" INTEGER DEFAULT 30,          -- max outbound calls allowed to be up
    "mixmonitor" TEXT,                    -- force mixmonitor on all recordings
    "monitor_out" TEXT DEFAULT '/var/spool/asterisk/monout/', -- monitorout folder
    "monitor_stage" TEXT DEFAULT '/var/spool/asterisk/monstage/', -- monstage folder - delete
    "name" TEXT,
    "number_range_regex" TEXT,
    "oclo" TEXT,
    "operator" INTEGER DEFAULT 100,
    "padminpass" INTEGER DEFAULT 44068,	-- phone browser ADMIN password - NOT HERE
    "puserpass" INTEGER DEFAULT 31524,	   -- phone browser USER password - NOT HERE
    "pickupgroup" TEXT,
    "play_beep" INTEGER DEFAULT 1,		-- play beep on failover
    "play_busy" INTEGER DEFAULT 1,		-- play busy message or tones
    "play_congested" INTEGER DEFAULT 1,	-- play congested message or tones
    "play_transfer" INTEGER DEFAULT 1,	-- play transfer message when transferring off the PBX
    "rec_age" INTEGER DEFAULT 60,			-- How long to keep voice recordings in days
    "rec_final_dest" TEXT,                -- recordings folder
    "rec_file_dlim" TEXT DEFAULT '_-_',     -- recordings filename delimiter - DELETE?
    "rec_grace" INTEGER DEFAULT 5,        -- recording grace period in delete folder before destruction 
    "rec_limit" INTEGER,                  -- Recording folder max size
    "rec_mount" TEXT,                   	-- Recording folder mount command
    "recmaxage" TEXT DEFAULT '60',		   -- Max age in days of call recordings for this tenant
    "recmaxsize" TEXT DEFAULT '0',		   -- Recording storage maximum for this tenant
    "recused" TEXT DEFAULT '0',			   -- Recording storage used by this tenant (updated according to cron freq)						
    "ringdelay" INTEGER DEFAULT 20,       -- default ring timeout (seconds)
    "routeoverride" TEXT,					   -- Holiday scheduler route override
    "spy_pass" TEXT DEFAULT '3333',       -- spy password
    "sysop" INTEGER,                      -- real operator extension
    "syspass" TEXT DEFAULT '4444',        -- password for sysops
    "usemohcustom" TEXT,
    "VDELAY" INTEGER DEFAULT 0,           -- artificial ring on inbound SIP
    "vmail_age" INTEGER DEFAULT 60,       -- vmail age
    "voice_instr" INTEGER DEFAULT 1,      -- play long or short Vmail instructions
    "voip_max" INTEGER DEFAULT 30,        -- MAX outbound up calls
    "vxt" INTEGER DEFAULT 0,				   -- Enable/disable VXT
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system'
);
/* open/closed automation */
CREATE TABLE IF NOT EXISTS dateseg (
    "id" TEXT PRIMARY KEY,                -- 27 char ksuid
    "shortuid" TEXT UNIQUE,                  -- human readable 8 char uid
    "pkey" INTEGER UNIQUE,             -- candidate to be removed
    "active" TEXT DEFAULT 'YES',
    "cluster" TEXT DEFAULT 'default',
    "cname" TEXT,
    "datemonth" TEXT DEFAULT '*',
    "dayofweek" TEXT DEFAULT '*',
    "description" TEXT DEFAULT '*NEW RULE*',
    "month" TEXT DEFAULT '*',
    "state" TEXT DEFAULT 'IDLE',
    "timespan" TEXT DEFAULT '*',
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system'
);
/* system greetings */
CREATE TABLE IF NOT EXISTS greeting (
    "id" TEXT PRIMARY KEY,                -- 27 char ksuid
    "shortuid" TEXT UNIQUE,                  -- human readable 8 char uid	
    "pkey" TEXT,
    "cname" TEXT,
    "filename" TEXT,
    "cluster" TEXT DEFAULT 'default',
    "description" TEXT,
    "type" TEXT,
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system'
);
/* Holiday overrides */
CREATE TABLE IF NOT EXISTS holiday (
    "id" TEXT PRIMARY KEY,                -- 27 char ksuid
    "shortuid" TEXT UNIQUE,                  -- human readable 8 char uid
    "pkey" TEXT,								      -- not really used but satisfies tuple builder
    "cluster" TEXT DEFAULT 'default',			-- tenant
    "cname" TEXT,
    "description" TEXT,								-- Description						
    "route" TEXT,								      -- Holiday scheduler route override
    "stime" INTEGER,							      -- Epoch start
    "etime" INTEGER,							      -- Epoch end
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system'
);
/* Extensions */
CREATE TABLE IF NOT EXISTS ipphone (
    "id" TEXT PRIMARY KEY,              -- 27 char ksuid    
    "shortuid" TEXT UNIQUE,                  -- human readable 8 char uid
    "pkey" TEXT NOT NULL, 
    "abstimeout" INTEGER DEFAULT 1440,
    "active" TEXT DEFAULT 'YES',			      -- Active/inactive flag
    "basemacaddr" TEXT,                      -- not used             
    "callerid" TEXT,                         -- CLID
    "callbackto" INTEGER DEFAULT 100,        -- who we callback (ext/cell)
    "cname" TEXT,                            -- common name
    "callmax" INTEGER DEFAULT 3,				      -- PJSIP does not support call-limit so we have to do it using GROUP
    "cellphone" TEXT,						      -- cellphone twin
    "celltwin" TEXT DEFAULT 'OFF',					      -- cell twin on/off
    "cluster" TEXT DEFAULT 'default',        -- Tenant
    -- desc is deprecated, use cname instead
    "desc" TEXT,                             -- asterisk username
    "description" TEXT,                      
    "device" TEXT,                           -- device vendor
    "devicemodel" TEXT,						      -- Harvested model number
    "devicerec" TEXT DEFAULT 'default',      -- recopts
    "dvrvmail" TEXT,                         -- mailbox
    "extalert" TEXT,                         -- alert info
    "macaddr" TEXT,                          -- mac address
    "passwd" TEXT,                           -- asterisk password
    "protocol" TEXT DEFAULT 'IPV4',			      -- IPV4/IPV6
    "pjsipuser" TEXT,						      -- Asterisk PJSIP string							
    "stealtime" INTEGER,                     -- epoch time this extension was stolen by HD
    "stolen" TEXT,                           -- HD thief 
    "technology" TEXT,                       -- SIP/IAX2/DiD/CLiD/Class
    "tls" TEXT,                              -- SSIP on/off
    "transport" TEXT DEFAULT 'udp',		      -- transport(udp/tcp/tls/wss)
    "vmailfwd" TEXT,
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    UNIQUE("cluster", "pkey")
);
/* Class of service */
CREATE TABLE IF NOT EXISTS ipphonecosopen (
    "id" TEXT,
    "cluster" TEXT DEFAULT 'default',
    "active" TEXT DEFAULT 'YES',
    "ipphone_pkey" TEXT,
    "cos_pkey" TEXT,
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    PRIMARY KEY (cluster, ipphone_pkey, cos_pkey)
);
/* Class of service */
CREATE TABLE IF NOT EXISTS ipphonecosclosed (
    "id" TEXT,
    "active" TEXT DEFAULT 'YES',
    "cluster" TEXT DEFAULT 'default',
    "ipphone_pkey" TEXT,
    "cos_pkey" TEXT,
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    PRIMARY KEY (cluster, ipphone_pkey, cos_pkey)
);
/* IVR menus */
CREATE TABLE IF NOT EXISTS ivrmenu (
    "id" TEXT PRIMARY KEY,              -- 27 char ksuid    
    "shortuid" TEXT UNIQUE,                  -- human readable 8 char uid	
    "pkey" TEXT NOT NULL,
    "active" TEXT DEFAULT 'YES',
    "alert0" TEXT,						-- Alertinfo for each keypress
    "alert1" TEXT,
    "alert10" TEXT,
    "alert11" TEXT,
    "alert2" TEXT,
    "alert3" TEXT,
    "alert4" TEXT,
    "alert5" TEXT,
    "alert6" TEXT,
    "alert7" TEXT,
    "alert8" TEXT,
    "alert9" TEXT,
    "cluster" TEXT DEFAULT 'default',
    "cname" TEXT,                            -- common name
    "description" TEXT DEFAULT 'None',
    "greetnum" TEXT DEFAULT 'None',			-- greeting number to play
    "listenforext" TEXT DEFAULT 'NO',
    -- name is deprecated and will be dropped in a near release use cname instead
    "name" TEXT,
    "option0" TEXT DEFAULT 'None',						      -- routed name for each keypress
    "option1" TEXT DEFAULT 'None',
    "option10" TEXT DEFAULT 'None',
    "option11" TEXT DEFAULT 'None',
    "option2" TEXT DEFAULT 'None',
    "option3" TEXT DEFAULT 'None',
    "option4" TEXT DEFAULT 'None',
    "option5" TEXT DEFAULT 'None',
    "option6" TEXT DEFAULT 'None',
    "option7" TEXT DEFAULT 'None',
    "option8" TEXT DEFAULT 'None',
    "option9" TEXT DEFAULT 'None',
    "tag0" TEXT,							      -- alphatag for each keypress
    "tag1" TEXT,
    "tag10" TEXT,
    "tag11" TEXT,
    "tag2" TEXT,
    "tag3" TEXT,
    "tag4" TEXT,
    "tag5" TEXT,
    "tag6" TEXT,
    "tag7" TEXT,
    "tag8" TEXT,
    "tag9" TEXT,
    "timeout" TEXT DEFAULT '30',		               -- timeout name 					
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    UNIQUE("cluster", "pkey")
);
/* inbound Routes (DiDs and CLIDs) */
CREATE TABLE IF NOT EXISTS inroutes (
    "id" TEXT PRIMARY KEY,              -- 27 char ksuid    
    "shortuid" TEXT UNIQUE,            -- human readable 8 char uid
    "pkey" TEXT NOT NULL,           -- inbound number, CLID or mask (in Asterisk format)
    "active" TEXT DEFAULT 'YES',	-- Active/inactive flag
    "alertinfo" TEXT,				-- distinctive ring
    "callback" TEXT,				-- denotes callback trunk
    "callerid" TEXT,				-- high-order (weak) CLID
    "callprogress" TEXT DEFAULT 'YES',		-- send progress tones on dial
    "closeroute" TEXT DEFAULT 'None',		-- closed inbound route
    "cluster" TEXT DEFAULT 'default',		-- cluster (Tenant) this trunk belongs to
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
    "openroute" TEXT DEFAULT 'None',		-- open inbound route
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
/* page groups */
CREATE TABLE IF NOT EXISTS page (
    "id" TEXT PRIMARY KEY,              -- 27 char ksuid    
    "shortuid" TEXT UNIQUE,                  -- human readable 8 char uid
    "pkey" TEXT NOT NULL,
    "active" TEXT DEFAULT 'YES',
    "cluster" TEXT DEFAULT 'default',
    "cname" TEXT,
    "description" TEXT,
    "pagegroup" TEXT,
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system'
);
/* conference rooms */
CREATE TABLE IF NOT EXISTS meetme (
    "id" TEXT PRIMARY KEY,                -- 27 char ksuid
    "shortuid" TEXT UNIQUE,                  -- human readable 8 char uid
    "pkey" INTEGER,
    "active" TEXT DEFAULT 'YES',
    "cluster" TEXT DEFAULT 'default',
    "cname" TEXT,
    "adminpin" TEXT DEFAULT 'None',
    "description" TEXT,
    "pin" TEXT DEFAULT 'None',
    "type" TEXT DEFAULT 'simple',
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system'
);
/* call queues */
CREATE TABLE IF NOT EXISTS queue (
    "id" TEXT PRIMARY KEY,                -- 27 char ksuid
    "shortuid" TEXT UNIQUE,               -- human readable 8 char uid
    "pkey" TEXT NOT NULL,
    "active" TEXT DEFAULT 'YES',
    "alertinfo" TEXT,
    "cluster" TEXT DEFAULT 'default',
    "cname" TEXT,
    "description" TEXT, 
    "devicerec" TEXT DEFAULT 'None',
    "divert" INTEGER,
    "greetnum" TEXT DEFAULT 'None',
    "greeting" TEXT DEFAULT 'None',       --N.B. will replace greetnum
    -- name is deprecated and will be dropped in a near release use cname instead
    "name" TEXT,                      --Human readable name
    "members" TEXT,                       --N.B. will replace OUT in speed
    "options" TEXT DEFAULT 'CiIknrtT',
    "musicclass" TEXT,
    "retry" INTEGER DEFAULT 1,
    "wrapuptime" INTEGER DEFAULT 0,
    "maxlen" INTEGER DEFAULT 0,
    "outcome" TEXT DEFAULT 'None',
    "strategy" TEXT DEFAULT 'ringall',    -- fine selection, all of the Asterisk types
    "timeout" INTEGER DEFAULT 30,
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    UNIQUE("cluster", "pkey")
);
/* Outbound routing */
CREATE TABLE IF NOT EXISTS route (
    "id" TEXT PRIMARY KEY,                -- 27 char ksuid
    "shortuid" TEXT UNIQUE,                  -- human readable 8 char uid	
    "pkey" TEXT NOT NULL,
    "active" TEXT DEFAULT 'YES',
    "alternate" TEXT,               -- alternate dial for desk to desk shortdial
    "auth" TEXT DEFAULT 'NO',       -- 1/0 used for pin dial
    "cluster" TEXT DEFAULT 'default',
    "cname" TEXT,
    "description" TEXT,  
    "dialplan" TEXT,                -- route dialplan
    "path1" TEXT DEFAULT 'None',
    "path2" TEXT DEFAULT 'None',
    "path3" TEXT DEFAULT 'None',
    "path4" TEXT DEFAULT 'None',
    "route" TEXT DEFAULT 'None',       -- always the same as pkey.   Not used, not needed.
    "strategy" TEXT DEFAULT 'hunt',   --hunt or balance
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    UNIQUE("cluster", "pkey")
);
/* trunks/gateways */
CREATE TABLE IF NOT EXISTS trunks (
    "id" TEXT PRIMARY KEY,              -- 27 char ksuid    
    "shortuid" TEXT UNIQUE,         -- human readable key
    "pkey" TEXT NOT NULL,
    "active" TEXT DEFAULT 'YES',	-- Active/inactive flag
    "alertinfo" TEXT,				-- distinctive ring
    "callback" TEXT,				-- denotes callback trunk
    "callerid" TEXT,				-- high-order (weak) CLID
    "callprogress" TEXT DEFAULT 'YES',		-- send progress tones on dial
    "closeroute" TEXT DEFAULT 'None',		-- closed inbound route
    "cluster" TEXT DEFAULT 'default',		-- cluster (Tenant) this trunk belongs to
    "cname" TEXT,
    "description" TEXT,			-- weak Asterisk username 
    "devicerec" TEXT DEFAULT 'default',		-- RECOPTS
    "disa" TEXT,					-- DISA capable trunk
    "disapass" TEXT,				-- DISA password
    "host" TEXT,					-- Host IP address
    "iaxreg" TEXT DEFAULT NULL,	-- Asterisk IAX registration (SND/RCV/NULL)		
    "inprefix" TEXT,				-- prepend prefix on inbound
    "match" TEXT,					-- trunk seize sequence
    "moh" TEXT DEFAULT 'NO',	-- play moh instead of ring
    "openroute" TEXT DEFAULT 'None',		-- open inbound route
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
    "z_updater" TEXT DEFAULT 'system',
    UNIQUE("cluster", "pkey")
);

COMMIT;

