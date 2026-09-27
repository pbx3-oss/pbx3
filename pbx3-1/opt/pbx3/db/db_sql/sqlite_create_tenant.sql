
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
    "domain" TEXT,                          -- domain name of this tenant (e.g. example.com)
    "emailalert" TEXT,                       -- email alert address
    "emergency" TEXT DEFAULT '999 112 911',  -- emergency numbers which bypass COS
    "extblklist" TEXT,                        -- Needs work!!!!!!!!!
    "ext_lim" INTEGER DEFAULT 0,             -- extlim for this tenant
    "ext_len" INTEGER DEFAULT 3,             -- extlen for this cluster
    "fqdn" TEXT DEFAULT NULL,                -- default is shortuid.domain
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
    "sched_mode" TEXT,                       -- day-parts current mode (timer); dual-read with oclo
    "holiday_force_mode" TEXT,               -- redesigned holiday (timer writes; optional)
    "holiday_force_dest" TEXT,               -- redesigned holiday dest (dual-read with routeoverride)
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
    "rec_s3" TEXT DEFAULT 'NO',			   -- S7: YES = upload archive to fleet recordings bucket (needs install capability)
    "ringdelay" INTEGER DEFAULT 20,       -- voip artificial ring timeout (seconds)
    "routeoverride" TEXT,					   -- Holiday scheduler route override
    "spy_pass" TEXT DEFAULT '',           -- spy password (empty = ChanSpy denied)
    "sysop" INTEGER,                      -- real operator extension
    "syspass" TEXT DEFAULT '',            -- password for sysops (empty = privileged keys denied)
    "usemohcustom" TEXT,
    "VDELAY" INTEGER DEFAULT 0,           -- artificial ring on inbound SIP
    "vmail_age" INTEGER DEFAULT 60,       -- vmail age
    "voice_instr" INTEGER DEFAULT 1,      -- play long or short Vmail instructions
    "voip_max" INTEGER DEFAULT 30,        -- MAX outbound up calls
    "vxt" INTEGER DEFAULT 0,				   -- Enable/disable VXT
    "park_overlay" TEXT,                     -- thin parking_lot overlay (tmpl key merge on Commit)
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system'
);
/* open/closed automation / day-parts windows */
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
    "mode" TEXT DEFAULT 'closed',      -- schedule mode asserted when window matches
    "priority" INTEGER DEFAULT 0,      -- higher wins on overlap (time-based routing Q3)
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
/* Holiday overrides (redesign: force_mode + force_dest; route kept for convert) */
CREATE TABLE IF NOT EXISTS holiday (
    "id" TEXT PRIMARY KEY,                -- 27 char ksuid
    "shortuid" TEXT UNIQUE,                  -- human readable 8 char uid
    "pkey" TEXT,								      -- not really used but satisfies tuple builder
    "cluster" TEXT DEFAULT 'default',			-- tenant
    "cname" TEXT,
    "description" TEXT,								-- Description						
    "route" TEXT,								      -- Legacy force dest (pbx3timer routeoverride path)
    "force_mode" TEXT,							      -- day-parts: mode when active (optional)
    "force_dest" TEXT,							      -- day-parts: dest override when active (optional)
    "stime" INTEGER,							      -- Epoch start (legacy import; product prefers calendar+TZ)
    "etime" INTEGER,							      -- Epoch end
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system'
);
/* Route profiles: tenant map mode → destination (reused across DIDs) */
CREATE TABLE IF NOT EXISTS route_profile (
    "id" TEXT PRIMARY KEY,
    "shortuid" TEXT UNIQUE,
    "pkey" TEXT,
    "cluster" TEXT DEFAULT 'default',
    "name" TEXT,
    "default_mode" TEXT DEFAULT 'open',
    "cname" TEXT,
    "description" TEXT,
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system'
);
CREATE TABLE IF NOT EXISTS route_profile_line (
    "id" TEXT PRIMARY KEY,
    "shortuid" TEXT UNIQUE,
    "profile" TEXT NOT NULL,               -- route_profile.shortuid
    "cluster" TEXT DEFAULT 'default',
    "mode" TEXT NOT NULL,                  -- open / closed / lunch / …
    "destination" TEXT NOT NULL,             -- same vocabulary as openroute/closeroute
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    UNIQUE("profile", "mode")
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
    "callbackto" TEXT DEFAULT 'desk',        -- who we callback (desk/cell)
    "cname" TEXT,                            -- common name
    "callmax" INTEGER DEFAULT 3,				      -- PJSIP does not support call-limit so we have to do it using GROUP
    "cellphone" TEXT,						      -- cellphone twin
    "celltwin" TEXT DEFAULT 'OFF',					      -- cell twin on/off
    "cluster" TEXT DEFAULT 'default',        -- Tenant
    -- desc is deprecated, use cname instead
    "desc" TEXT,                             -- asterisk username
    "description" TEXT,                      -- Freeform description
    "device" TEXT,                           -- type only: WebRTC | MAILBOX | General SIP (brand → devicevendor)
    "devicevendor" TEXT,                     -- Harvested brand from SIP UA (cron harvest; not SPA-writable)
    "devicemodel" TEXT,						 -- Harvested model token from SIP UA (e.g. T46U)
    "devicerec" TEXT DEFAULT 'default',      -- recoptsdatabse desc
    "dvrvmail" TEXT,                         -- mailbox
    "extalert" TEXT,                         -- alert info
    "firstseen" TEXT,                        -- UTC ISO: first UA harvest observe (repurposed; was provision)
    "lastseen" TEXT,                         -- UTC ISO: latest UA harvest observe
    "macaddr" TEXT,                          -- optional best-effort inventory (not vendor canon)
    "passwd" TEXT,                           -- asterisk password
    "protocol" TEXT DEFAULT 'IPV4',			 -- IPV4/IPV6
    "provision" TEXT,                        -- provisioning string with #INCLUDE directives
    "provisionwith" TEXT DEFAULT 'IP',       -- how to provision: IP or FQDN
    "pjsipuser" TEXT,						 -- DEPRECATED 2026-08-23: was Device.sipiaxfriend copy; GenAst uses pjsip_overlay. Keep until schema drop.
    "stealtime" INTEGER,                     -- epoch time this extension was stolen by HD
    "stolen" TEXT,                           -- HD thief 
    "technology" TEXT,                       -- SIP/IAX2/DiD/CLiD/Class
    "tls" TEXT,                              -- SSIP on/off
    "transport" TEXT DEFAULT 'udp',		     -- transport(udp/tcp/tls/wss)
    "vmailfwd" TEXT,                         -- vmail forward email address
    "pjsip_overlay" TEXT,                    -- thin PJSIP phone overlay (tmpl key merge on Commit)
    "named_call_group" TEXT DEFAULT 'ALL',   -- PJSIP named_call_group (groups this phone is in); ALL/empty → GenAst $clst
    "named_pickup_group" TEXT DEFAULT 'ALL', -- PJSIP named_pickup_group (groups this phone can pickup); ALL/empty → GenAst $clst
    "cos_profile" TEXT,                      -- cos_profile.pkey (tenant-scoped); GenAst HoR after Slice B
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    UNIQUE("cluster", "pkey"),
    UNIQUE("macaddr")
);
/* CoS profiles: named phone class (Staff / Lobby / …) — Standard + After-hours rule sets */
CREATE TABLE IF NOT EXISTS cos_profile (
    "id" TEXT PRIMARY KEY,
    "shortuid" TEXT UNIQUE,
    "pkey" TEXT NOT NULL,
    "active" TEXT DEFAULT 'YES',
    "cluster" TEXT DEFAULT 'default',
    "cname" TEXT,
    "description" TEXT,
    "is_default" TEXT DEFAULT 'NO',
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    UNIQUE("cluster", "pkey")
);
CREATE TABLE IF NOT EXISTS cos_profile_open (
    "id" TEXT,
    "cluster" TEXT DEFAULT 'default',
    "active" TEXT DEFAULT 'YES',
    "profile_pkey" TEXT,
    "cos_pkey" TEXT,
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    PRIMARY KEY (cluster, profile_pkey, cos_pkey)
);
CREATE TABLE IF NOT EXISTS cos_profile_closed (
    "id" TEXT,
    "cluster" TEXT DEFAULT 'default',
    "active" TEXT DEFAULT 'YES',
    "profile_pkey" TEXT,
    "cos_pkey" TEXT,
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    PRIMARY KEY (cluster, profile_pkey, cos_pkey)
);
/* Class of service (per-phone junctions — retained; GenAst ignores after profiles authoritative) */
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
    "closeroute" TEXT DEFAULT 'None',		-- closed inbound route (dual-read; demote when profile used)
    "cluster" TEXT DEFAULT 'default',		-- cluster (Tenant) this trunk belongs to
    "cname" TEXT,
    "description" TEXT,			-- weak Asterisk username 
    "devicerec" TEXT,			-- RECOPTS
    "disa" TEXT,					-- DISA capable trunk
    "disapass" TEXT,				-- DISA password
    "entry_dest" TEXT,			-- always-this dest (skip schedule) when set
    "host" TEXT,					-- Host IP address
    "iaxreg" TEXT DEFAULT NULL,	-- Asterisk IAX registration (SND/RCV/NULL)		
    "inprefix" TEXT,				-- prepend prefix on inbound
    "match" TEXT,					-- trunk seize sequence
    "moh" TEXT DEFAULT 'NO',	-- play moh instead of ring
    "openroute" TEXT DEFAULT 'None',		-- open inbound route (dual-read)
    "route_profile" TEXT,			-- route_profile.shortuid (tenant-scoped)
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
    "timeout" INTEGER DEFAULT 30,         -- Agent Ring Timeout (queues.conf timeout)
    "caller_timeout" INTEGER,             -- Caller Max Wait (Queue() 5th arg); NULL/0 = unlimited
    "queue_overlay" TEXT,                 -- thin queue.conf overlay (flat KV merge on Commit)
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
/* Per-calling-tenant dial prefixes (short dial A′ Q14) — prefix → target tenant FQDN; moves with miniDB */
CREATE TABLE IF NOT EXISTS dialalias (
    "id" TEXT PRIMARY KEY,                  -- 27 char ksuid
    "shortuid" TEXT UNIQUE,                 -- human readable 8 char uid
    "pkey" TEXT NOT NULL,                   -- dial prefix digits (2–4), unique per calling tenant
    "active" TEXT DEFAULT 'YES',
    "cluster" TEXT DEFAULT 'default',       -- calling tenant shortuid
    "target_cluster" TEXT,                  -- optional target shortuid (label / rename pin)
    "target_fqdn" TEXT NOT NULL,            -- dial target: full tenant FQDN (never instance FQDN)
    "cname" TEXT,
    "description" TEXT,
    "source" TEXT DEFAULT 'manual',         -- manual | cohort (Site Group projection)
    "cohort_id" TEXT,                       -- dial cohort id when source=cohort
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    UNIQUE("cluster", "pkey")
);

/* Call recording index (Phase R1.5+) — tenant-scoped; moves with miniDB export */
CREATE TABLE IF NOT EXISTS recordings (
    "id" TEXT PRIMARY KEY,
    "cluster" TEXT NOT NULL,
    "epoch" INTEGER NOT NULL,
    "callerid" TEXT,
    "dnid" TEXT,
    "queue" TEXT,
    "extension" TEXT,
    "filename" TEXT NOT NULL,
    "local_path" TEXT,
    "s3_key" TEXT,
    "location" TEXT NOT NULL DEFAULT 'spool',
    "filesize" INTEGER,
    "deleted_at" datetime,
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    UNIQUE("cluster", "filename")
);
CREATE INDEX IF NOT EXISTS idx_recordings_cluster_epoch ON recordings ("cluster", "epoch");
CREATE INDEX IF NOT EXISTS idx_recordings_cluster_callerid ON recordings ("cluster", "callerid");
CREATE INDEX IF NOT EXISTS idx_recordings_cluster_dnid ON recordings ("cluster", "dnid");

/* Tenant CLID block list — inbound caller ID reject (greenfield; moves with miniDB) */
CREATE TABLE IF NOT EXISTS clid_block (
    "id" TEXT PRIMARY KEY,
    "shortuid" TEXT UNIQUE,
    "pkey" TEXT NOT NULL,
    "active" TEXT DEFAULT 'YES',
    "cluster" TEXT DEFAULT 'default',
    "action" TEXT DEFAULT 'hangup',
    "cname" TEXT,
    "description" TEXT,
    "z_created" datetime,
    "z_updated" datetime,
    "z_updater" TEXT DEFAULT 'system',
    UNIQUE("cluster", "pkey")
);
CREATE INDEX IF NOT EXISTS idx_clid_block_cluster_pkey ON clid_block ("cluster", "pkey");

COMMIT;

