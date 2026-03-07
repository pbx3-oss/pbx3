
BEGIN TRANSACTION;

/* Agent */
CREATE TABLE IF NOT EXISTS Agent (
id TEXT PRIMARY KEY,	
pkey INTEGER NOT NULL,
cluster TEXT DEFAULT 'default',
conf TEXT,
extlen INTEGER,
-- name is deprecated and will be dropped in a near release use cname instead
name TEXT DEFAULT '*NEW AGENT*', 
cname TEXT DEFAULT '*NEW AGENT*',
num TEXT,
passwd TEXT,				
queue1 TEXT DEFAULT 'None',
queue2 TEXT DEFAULT 'None',
queue3 TEXT DEFAULT 'None',
queue4 TEXT DEFAULT 'None',
queue5 TEXT DEFAULT 'None',
queue6 TEXT DEFAULT 'None',
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system'
);

/* Custom App */
CREATE TABLE IF NOT EXISTS Appl (
id TEXT PRIMARY KEY,
pkey TEXT NOT NULL,
active TEXT DEFAULT 'YES',
cluster TEXT DEFAULT 'default',
description TEXT,
extcode TEXT,
-- name is deprecated and will be dropped in a near release use cname instead
name TEXT,
cname TEXT,                            -- common name
span TEXT DEFAULT 'Neither',
striptags TEXT,
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system'
);

/* Class of service */
CREATE TABLE IF NOT EXISTS COS (
id TEXT PRIMARY KEY,
pkey TEXT NOT NULL,
active TEXT DEFAULT 'YES',
cluster TEXT,
cname TEXT,
defaultclosed TEXT DEFAULT 'NO',
defaultopen TEXT  DEFAULT 'NO',
description TEXT,
dialplan TEXT DEFAULT NULL, 
orideclosed TEXT DEFAULT 'NO', 
orideopen TEXT DEFAULT 'NO',
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system'
);

/* Tenant/Cluster */
CREATE TABLE IF NOT EXISTS Cluster (
id TEXT PRIMARY KEY,	
pkey TEXT NOT NULL,
abstimeout INTEGER DEFAULT 14400,
acl boolean DEFAULT false,
allow_hash_xfer  TEXT DEFAULT 'enabled',                 -- Allow asterisk non-SIP xfer
blind_busy TEXT,                     -- blind transfer busy bounce
bounce_alert TEXT,
callrecord_1 TEXT DEFAULT 'None',      -- alertinfo string for blind transfer bounce
camp_on_q_onoff TEXT,                  -- camp-on miniqueue enable
camp_on_q_opt TEXT,                    -- camp-on miniqueue options
cfwdextern_rule TEXT DEFAULT 'YES',    -- allow call forward to external numbers 
cfwd_progress  TEXT DEFAULT 'enabled', -- turn on early-media,
cfwd_answer   TEXT DEFAULT 'enabled',  -- take call off-hook before forward to external
clusterclid TEXT,
chanmax INTEGER DEFAULT 3,             -- maximum up channels for this tenant
countrycode INTEGER DEFAULT 44,			-- countrycode
dynamicfeatures TEXT DEFAULT NULL,  -- Asterisk DYNAMIC_FEATURES string		
description TEXT,       
devicerec TEXT DEFAULT 'default',	   -- recording settings for this tenant
emailalert TEXT,                       -- email alert address
emergency TEXT DEFAULT '999 112 911',  -- emergency numbers which bypass COS
extblklist TEXT,                        -- Needs work!!!!!!!!!
ext_lim INTEGER DEFAULT 0,             -- extlim for this tenant
ext_len INTEGER DEFAULT 3,             -- extlen for this cluster
fqdn TEXT DEFAULT NULL,                --TRANSFORM!
fqdninspect boolean default false,     --TRANSFORM!
include TEXT,                          -- list of other tenants which may be short-dialled
int_ring_delay INTEGER DEFAULT 20,		-- ring time before voicemail
ivr_key_wait INTEGER DEFAULT 6,        -- how long to wait after keypress
ivr_digit_wait INTEGER DEFAULT 6000,   -- how long to wait for another digit
language TEXT DEFAULT 'en-gb',         -- used in extensions.conf 
ldapanonbind TEXT DEFAULT 'YES',       -- anonymous bind YES/NO **MOVED**
ldapbase text DEFAULT 'dc=sark,dc=local',  -- LDAP base **MOVED**
ldaphost TEXT DEFAULT '127.0.0.1',  -- LDAP host **MOVED**
ldapou text DEFAULT 'contacts',     -- LDAP OU **MOVED**
ldapuser text DEFAULT 'admin',		-- LDAP user **MOVED**
ldappass text DEFAULT 'sarkadmin',	-- LDAP password **MOVED**
ldaptls DEFAULT 'off',              -- LDAP TLS mode(off/on)
localarea TEXT,                        -- local area code
localdplan TEXT,                       -- local number dialplan
lterm INTEGER DEFAULT 0,			   -- late termination flag
leasedhdtime INTEGER DEFAULT 43200,		-- Hot desk lease time
masteroclo TEXT,
maxin INTEGER DEFAULT 30,          -- max inbound calls allowed to be up
maxout INTEGER DEFAULT 30,          -- max inbound calls allowed to be up
mixmonitor TEXT,                    -- force mixmonitor on all recordings
monitor_out TEXT DEFAULT '/var/spool/asterisk/monout/', -- monitorout folder
monitor_stage TEXT DEFAULT '/var/spool/asterisk/monstage/', -- monstage folder - delete
name TEXT,
cname TEXT,                         -- cname replaces Name
number_range_regex TEXT,
oclo TEXT,
operator INTEGER DEFAULT 100,
padminpass INTEGER DEFAULT 44068,	-- phone browser ADMIN passord - NOT HERE
puserpass INTEGER DEFAULT 31524,	   -- phone browser USER passord - NOT HERE
pickupgroup TEXT,
play_beep INTEGER DEFAULT 1,		-- play beep on failover
play_busy INTEGER DEFAULT 1,		-- play busy message or tones
play_congested INTEGER DEFAULT 1,	-- play congested message or tones
play_transfer INTEGER DEFAULT 1,	-- play transfer message when transferring off the PBX
rec_age INTEGER DEFAULT 60,			-- How long to keep voice recordings in days
rec_final_dest TEXT,                -- recordings folder
rec_file_dlim TEXT DEFAULT '_-_',     -- recordings filename delimiter - DELETE
rec_grace INTEGER DEFAULT 5,        -- recording grace period in delete folder before destruction 
rec_limit INTEGER,                  -- Recording folder max size
rec_mount TEXT,                   	-- Recording folder mount command
recmaxage TEXT DEFAULT '60',		   -- Max age in days of call recordings for this tenant
recmaxsize TEXT DEFAULT '0',		   -- Recording storage maximum for this tenant
recused TEXT DEFAULT '0',			   -- Recording storage used by this tenant (updated according to cron freq)						
ringdelay INTEGER DEFAULT 20,       -- default ring timeout (seconds)
routeoverride TEXT,					   -- Holiday scheduler route override
spy_pass TEXT DEFAULT '3333',       -- spy password
sysop INTEGER,                      -- real operator extension
syspass TEXT DEFAULT '4444',        -- password for sysops
usemohcustom TEXT,
VDELAY INTEGER DEFAULT 0,           -- artificial ring on inbound SIP
vmail_age INTEGER DEFAULT 60,       -- vmail age
voice_instr INTEGER DEFAULT 1,      -- play long or short Vmail instructions
voip_max INTEGER DEFAULT 30,        -- MAX outbound up calls
vxt INTEGER DEFAULT 0,				   -- Enable/disable VXT
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system'
);

/* open/closed automation */
CREATE TABLE IF NOT EXISTS dateSeg (
id TEXT PRIMARY KEY,
pkey INTEGER UNIQUE,             -- candidate to be removed
cluster TEXT DEFAULT 'default',
datemonth TEXT DEFAULT '*',
dayofweek TEXT DEFAULT '*',
description TEXT DEFAULT '*NEW RULE*',
month TEXT DEFAULT '*',
state TEXT DEFAULT 'IDLE',
timespan TEXT DEFAULT '*',
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system',
UNIQUE (pkey)
);

/* system greetings */
CREATE TABLE IF NOT EXISTS Greeting (
id TEXT PRIMARY KEY,	
pkey TEXT,
cname TEXT,
filename TEXT,
cluster TEXT DEFAULT 'default',
description TEXT,
type TEXT,
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system'
);

/* Holiday overrides */
CREATE TABLE IF NOT EXISTS Holiday (
id TEXT PRIMARY KEY,
pkey TEXT,								      -- not really used but satisfies tuple builder
cluster TEXT DEFAULT 'default',			-- tenant
cname TEXT,
description TEXT,								-- Description						
route TEXT,								      -- Holiday scheduler route override
routeclass TEXT,								-- Holiday scheduler routeclass override
stime INTEGER,							      -- Epoch start
etime INTEGER,							      -- Epoch end
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system'
);

/* Extensions */
CREATE TABLE IF NOT EXISTS IPphone (
id TEXT,
pkey TEXT, 
abstimeout INTEGER DEFAULT 1440,
active TEXT DEFAULT 'YES',			      -- Active/inactive flag
basemacaddr TEXT,                      -- not used             
callerid TEXT,                         -- CLID
callbackto INTEGER DEFAULT 100,        -- who we callback (ext/cell)
cname TEXT,                            -- common name
callmax TEXT DEFAULT 3,				      -- PJSIP does not support call-limit so we have to do it using GROUP
cellphone TEXT,						      -- cellphone twin
celltwin TEXT,							      -- cell twin on/off
cluster TEXT DEFAULT 'default',        -- Tenant
-- desc is deprecated, use cname instead
desc TEXT,
description TEXT,                      -- asterisk username
device TEXT,                           -- device vendor
devicemodel TEXT,						      -- Harvested model number
devicerec TEXT DEFAULT 'default',      -- recopts
dvrvmail TEXT,                         -- mailbox
extalert TEXT,                         -- alert info
firstseen TEXT,						      -- first date provisioned (or NULL)
lastseen TEXT,							      -- last date provisioned (or NULL)
macaddr TEXT,                          -- mac address
passwd TEXT,                           -- asterisk password
protocol DEFAULT 'IPV4',			      -- IPV4/IPV6
pjsipuser TEXT,						      -- Asterisk PJSIP string							
provision TEXT,                        -- provisioning string 
provisionwith TEXT DEFAULT 'IP',	      -- how to provision my id - IP address or FQDN   
sndcreds TEXT DEFAULT 'Always',        -- send creds with provisioning
stealtime INTEGER,                     -- epoch time this extension was stolen by HD
stolen TEXT,                           -- HD thief 
technology TEXT,                       -- SIP/IAX2/DiD/CLiD/Class
tls TEXT,                              -- SSIP on/off
transport TEXT DEFAULT 'udp',		      -- transport(udp/tcp/tls/wss)
vmailfwd TEXT,
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system',
PRIMARY KEY (pkey,cluster)
);

/* Class of service */
CREATE TABLE IF NOT EXISTS IPphoneCOSopen (
id TEXT,
cluster TEXT,
IPphone_pkey TEXT,
COS_pkey TEXT,
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system',
PRIMARY KEY (IPphone_pkey, COS_pkey)
);

/* Class of service */
CREATE TABLE IF NOT EXISTS IPphoneCOSclosed (
id TEXT,
cluster TEXT,
IPphone_pkey TEXT,
COS_pkey TEXT,
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system',
PRIMARY KEY (IPphone_pkey, COS_pkey)
);

/* IVR menus */
CREATE TABLE IF NOT EXISTS ivrmenu (
id TEXT,	
pkey TEXT NOT NULL,
alert0 TEXT,						-- Alertinfo for each keypress
alert1 TEXT,
alert10 TEXT,
alert11 TEXT,
alert2 TEXT,
alert3 TEXT,
alert4 TEXT,
alert5 TEXT,
alert6 TEXT,
alert7 TEXT,
alert8 TEXT,
alert9 TEXT,
cluster TEXT,
description TEXT DEFAULT 'None',
greetnum TEXT DEFAULT 'None',			-- greeting number to play
listenforext TEXT DEFAULT 'NO',
-- name is deprecated and will be dropped in a near release use cname instead
name TEXT,
cname TEXT,                            -- common name
option0 TEXT DEFAULT 'None',						      -- routed name for each keypress
option1 TEXT DEFAULT 'None',
option10 TEXT DEFAULT 'None',
option11 TEXT DEFAULT 'None',
option2 TEXT DEFAULT 'None',
option3 TEXT DEFAULT 'None',
option4 TEXT DEFAULT 'None',
option5 TEXT DEFAULT 'None',
option6 TEXT DEFAULT 'None',
option7 TEXT DEFAULT 'None',
option8 TEXT DEFAULT 'None',
option9 TEXT DEFAULT 'None',
routeclass0 TEXT,					      -- routeclass for each keypress
routeclass1 TEXT,
routeclass10 TEXT,
routeclass11 TEXT,
routeclass2 TEXT,
routeclass3 TEXT,
routeclass4 TEXT,
routeclass5 TEXT,
routeclass6 TEXT,
routeclass7 TEXT,
routeclass8 TEXT,
routeclass9 TEXT,
tag0 TEXT,							      -- alphatag for each keypress
tag1 TEXT,
tag10 TEXT,
tag11 TEXT,
tag2 TEXT,
tag3 TEXT,
tag4 TEXT,
tag5 TEXT,
tag6 TEXT,
tag7 TEXT,
tag8 TEXT,
tag9 TEXT,
timeout TEXT,			               -- timeout name
timeoutrouteclass TEXT,	            -- timeout routeclass 					
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system',
PRIMARY KEY (pkey,cluster)
);

/* trunks/gateways */
CREATE TABLE IF NOT EXISTS lineIO (
id TEXT,
pkey TEXT PRIMARY KEY,
active TEXT DEFAULT 'YES',	-- Active/inactive flag
alertinfo TEXT,				-- distinctive ring
callback TEXT,				-- denotes callback trunk
callerid TEXT,				-- high-order (weak) CLID
callprogress TEXT DEFAULT 'YES',		-- send progress tones on dial
closeroute TEXT,			-- closed inbound route
cluster TEXT,				-- cluster (Tenant) this trunk belongs to
cname TEXT,
description TEXT,			-- weak Asterisk username 
devicerec TEXT,			-- RECOPTS
disa TEXT,					-- DISA capable trunk
disapass TEXT,				-- DISA password
host TEXT,					-- Host IP address
iaxreg TEXT DEFAULT NULL,	-- Asterisk IAX registration (SND/RCV/NULL)		
inprefix TEXT,				-- prepend prefix on inbound
match TEXT,					-- trunk seize sequence
moh TEXT DEFAULT 'NO',	-- play moh instead of ring
openroute TEXT,			-- open inbound route
password TEXT,				-- far end password
peername TEXT,				-- strong Asterisk username
pjsipreg TEXT DEFAULT NULL,	-- Asterisk pjsip registration (SND/RCV/NULL)									
privileged TEXT,			-- privileged ingress 
register TEXT,				-- registration string
routeclassopen TEXT,		-- routeclass
routeclassclosed TEXT,		-- routeclass
swoclip TEXT DEFAULT 'YES',	-- Switch On CLIP
tag TEXT,					-- Alpha tag
technology TEXT,           -- SIP/IAX2/DiD/CLiD/Class
transform TEXT,				-- Transformation mask
transport TEXT DEFAULT 'udp',
trunkname TEXT,				-- freeform trunkname
username TEXT,				-- far end username
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system'
);

/* new inroute table  - DiD/CLiD/Class*/
CREATE TABLE IF NOT EXISTS inroutes (
id TEXT,
pkey TEXT PRIMARY KEY,
active TEXT DEFAULT 'YES',	-- Active/inactive flag
alertinfo TEXT,				-- distinctive ring
callback TEXT,				-- denotes callback trunk
callerid TEXT,				-- high-order (weak) CLID
callprogress TEXT DEFAULT 'YES',		-- send progress tones on dial
closeroute TEXT,			-- closed inbound route
cluster TEXT,				-- cluster (Tenant) this trunk belongs to
cname TEXT,
description TEXT,			-- weak Asterisk username 
devicerec TEXT,			-- RECOPTS
disa TEXT,					-- DISA capable trunk
disapass TEXT,				-- DISA password
host TEXT,					-- Host IP address
iaxreg TEXT DEFAULT NULL,	-- Asterisk IAX registration (SND/RCV/NULL)		
inprefix TEXT,				-- prepend prefix on inbound
match TEXT,					-- trunk seize sequence
moh TEXT DEFAULT 'NO',	-- play moh instead of ring
openroute TEXT,			-- open inbound route
password TEXT,				-- far end password
peername TEXT,				-- strong Asterisk username
pjsipreg TEXT DEFAULT NULL,	-- Asterisk pjsip registration (SND/RCV/NULL)									
privileged TEXT,			-- privileged ingress 
register TEXT,				-- registration string
routeclassopen TEXT,		-- routeclass
routeclassclosed TEXT,		-- routeclass
swoclip TEXT DEFAULT 'YES',	-- Switch On CLIP
tag TEXT,					-- Alpha tag
technology TEXT,           -- SIP/IAX2/DiD/CLiD/Class
transform TEXT,				-- Transformation mask
transport TEXT DEFAULT 'udp',
trunkname TEXT,				-- freeform trunkname
username TEXT,				-- far end username
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system'
);

/* new trunk table */
CREATE TABLE IF NOT EXISTS trunks (
id TEXT,
pkey TEXT PRIMARY KEY,
active TEXT DEFAULT 'YES',	-- Active/inactive flag
alertinfo TEXT,				-- distinctive ring
callback TEXT,				-- denotes callback trunk
callerid TEXT,				-- high-order (weak) CLID
callprogress TEXT DEFAULT 'YES',		-- send progress tones on dial
closeroute TEXT,			-- closed inbound route
cluster TEXT,				-- cluster (Tenant) this trunk belongs to
cname TEXT,
description TEXT,			-- weak Asterisk username 
devicerec TEXT,			-- RECOPTS
disa TEXT,					-- DISA capable trunk
disapass TEXT,				-- DISA password
host TEXT,					-- Host IP address
iaxreg TEXT DEFAULT NULL,	-- Asterisk IAX registration (SND/RCV/NULL)		
inprefix TEXT,				-- prepend prefix on inbound
match TEXT,					-- trunk seize sequence
moh TEXT DEFAULT 'NO',	-- play moh instead of ring
openroute TEXT,			-- open inbound route
password TEXT,				-- far end password
peername TEXT,				-- strong Asterisk username
pjsipreg TEXT DEFAULT NULL,	-- Asterisk pjsip registration (SND/RCV/NULL)									
privileged TEXT,			-- privileged ingress 
register TEXT,				-- registration string
routeclassopen TEXT,		-- routeclass
routeclassclosed TEXT,		-- routeclass
swoclip TEXT DEFAULT 'YES',	-- Switch On CLIP
tag TEXT,					-- Alpha tag
technology TEXT,           -- SIP/IAX2/DiD/CLiD/Class
transform TEXT,				-- Transformation mask
transport TEXT DEFAULT 'udp',
trunkname TEXT,				-- freeform trunkname
username TEXT,				-- far end username
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system'
);

/* page groups */
CREATE TABLE IF NOT EXISTS page (
pkey TEXT PRIMARY KEY,
cluster TEXT,
cname TEXT,
pagegroup TEXT,
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system'
);

/* conference rooms */
CREATE TABLE IF NOT EXISTS meetme (
id TEXT PRIMARY KEY,
pkey INTEGER,
cluster TEXT DEFAULT 'default',
cname TEXT,
adminpin TEXT DEFAULT 'None',
description TEXT,
pin TEXT DEFAULT 'None',
type TEXT DEFAULT 'simple',
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system'
);

/* call queues */
CREATE TABLE IF NOT EXISTS Queue (
id TEXT,
pkey TEXT,
active TEXT DEFAULT 'YES',
alertinfo TEXT,
cluster TEXT,
description TEXT, 
devicerec TEXT,
divert INTEGER,
greetnum TEXT DEFAULT 'None',
greeting TEXT DEFAULT 'None',       --N.B. will replace greetnum
-- name is deprecated and will be dropped in a near release use cname instead
name TEXT,                      --Human readable name
cname TEXT,                            -- common name
members TEXT,                       --N.B. will replace OUT in speed
options TEXT DEFAULT 'CiIknrtT',
musicclass TEXT,
retry INTEGER DEFAULT 1,
wrapuptime INTEGER DEFAULT 0,
maxlen INTEGER DEFAULT 0,
outcome TEXT DEFAULT 'None',
outcomerouteclass TEXT,
strategy TEXT DEFAULT 'ringall',    -- fine selection, all of the Asterisk types
timeout INTEGER DEFAULT 30,
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system',
PRIMARY KEY (pkey,cluster)
);

/* Outbound routing */
CREATE TABLE IF NOT EXISTS Route (
id TEXT PRIMARY KEY,	
pkey TEXT,
active TEXT DEFAULT 'YES',
alternate TEXT,               -- alternate dial for desk to desk shortdial
auth TEXT DEFAULT 'NO',       -- 1/0 used for pin dial
cluster TEXT,
cname TEXT,
description TEXT,  
dialplan TEXT,                -- route dialplan
path1 TEXT DEFAULT 'None',
path2 TEXT DEFAULT 'None',
path3 TEXT DEFAULT 'None',
path4 TEXT DEFAULT 'None',
route TEXT DEFAULT 'None',       -- always the same as pkey.   Not used, not needed.
strategy TEXT DEFAULT 'hunt',   --hunt or balance
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system'
);

/* callgroups  - Deprecated being dropped  */
CREATE TABLE IF NOT EXISTS speed (
id TEXT,	
pkey INT,
callerid TEXT,
calleridname TEXT,
cluster TEXT,
description TEXT,
devicerec TEXT,
dialparamshunt TEXT DEFAULT 'ciIkt',
dialparamsring TEXT DEFAULT 'cIkt',
divert TEXT,
greeting TEXT,
grouptype TEXT,
longdesc TEXT,
obeydnd TEXT,
out TEXT,
outcome TEXT,
outcomerouteclass TEXT,
pagegroup TEXT,
ringdelay INTEGER DEFAULT 15,
speedalert TEXT,
trunk TEXT,
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system',
PRIMARY KEY (pkey,cluster)
);

/* Laravel tanles - these live with the instance and are universal to the instance */

CREATE TABLE IF NOT EXISTS "migrations"(
  "id" integer primary key autoincrement not null,
  "migration" varchar not null,
  "batch" integer not null
);
CREATE TABLE IF NOT EXISTS "users"(
  "id" integer primary key,
  /* cluster added to handle cluster migration */
  "cluster" varchar DEFAULT "default",
  "name" varchar not null,
  "email" varchar not null,
  "email_verified_at" datetime,
  "password" varchar not null,
  "role" varchar DEFAULT null,
  "remember_token" varchar,
  "created_at" datetime,
  "updated_at" datetime
);
CREATE UNIQUE INDEX "users_email_unique" on "users"("email");
CREATE TABLE IF NOT EXISTS "password_reset_tokens"(
  "email" varchar not null,
  "token" varchar not null,
  "created_at" datetime,
  primary key("email")
);
CREATE TABLE IF NOT EXISTS "sessions"(
  "id" varchar not null,
  "user_id" integer,
  "ip_address" varchar,
  "user_agent" text,
  "payload" text not null,
  "last_activity" integer not null,
  primary key("id")
);
CREATE INDEX "sessions_user_id_index" on "sessions"("user_id");
CREATE INDEX "sessions_last_activity_index" on "sessions"("last_activity");
CREATE TABLE IF NOT EXISTS "cache"(
  "key" varchar not null,
  "value" text not null,
  "expiration" integer not null,
  primary key("key")
);
CREATE TABLE IF NOT EXISTS "cache_locks"(
  "key" varchar not null,
  "owner" varchar not null,
  "expiration" integer not null,
  primary key("key")
);
CREATE TABLE IF NOT EXISTS "jobs"(
  "id" integer primary key autoincrement not null,
  "queue" varchar not null,
  "payload" text not null,
  "attempts" integer not null,
  "reserved_at" integer,
  "available_at" integer not null,
  "created_at" integer not null
);
CREATE INDEX "jobs_queue_index" on "jobs"("queue");
CREATE TABLE IF NOT EXISTS "job_batches"(
  "id" varchar not null,
  "name" varchar not null,
  "total_jobs" integer not null,
  "pending_jobs" integer not null,
  "failed_jobs" integer not null,
  "failed_job_ids" text not null,
  "options" text,
  "cancelled_at" integer,
  "created_at" integer not null,
  "finished_at" integer,
  primary key("id")
);
CREATE TABLE IF NOT EXISTS "failed_jobs"(
  "id" integer primary key autoincrement not null,
  "uuid" varchar not null,
  "connection" text not null,
  "queue" text not null,
  "payload" text not null,
  "exception" text not null,
  "failed_at" datetime not null default CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX "failed_jobs_uuid_unique" on "failed_jobs"("uuid");
CREATE TABLE IF NOT EXISTS "personal_access_tokens"(
  "id" integer primary key autoincrement not null,
  "tokenable_type" varchar not null,
  "tokenable_id" integer not null,
  "name" varchar not null,
  "token" varchar not null,
  "abilities" text,
  "last_used_at" datetime,
  "expires_at" datetime,
  "created_at" datetime,
  "updated_at" datetime
);
CREATE INDEX "personal_access_tokens_tokenable_type_tokenable_id_index" on "personal_access_tokens"(
  "tokenable_type",
  "tokenable_id"
);
CREATE UNIQUE INDEX "personal_access_tokens_token_unique" on "personal_access_tokens"(
  "token"
);


/* SYSTEM TABLES - these are not backed up as part of a cluster backup */

/* system settings */
CREATE TABLE IF NOT EXISTS globals (
pkey TEXT PRIMARY KEY,
ABSTIMEOUT INTEGER DEFAULT 14400,   -- default abstimeout 4 hours **MOVED**
BINDADDR TEXT,                      -- Asterisk SIP bindaddr
BINDPORT TEXT DEFAULT 5060,			-- SIP BINDPORT
COSSTART TEXT DEFAULT 'ON',            -- COS onoff
EDOMAIN TEXT,                       -- external IP address of this server
EMERGENCY TEXT DEFAULT '999 112 911',  -- **MOVED**
EXTLEN INTEGER DEFAULT 5,				-- extension length - deprecated
FQDN TEXT,							-- FQDN - NEEDS TO MOVE
FQDNINSPECT TEXT DEFAULT 'NO',		-- Require FQDN in SIP Ops Shorewall 4.6+ 
FQDNPROV TEXT,						-- use FQDN in remote provisioning YES/NO
LANGUAGE TEXT DEFAULT 'en-gb',      -- used in extensions.conf 
LOCALIP TEXT,                       -- local ip address
LOGLEVEL INTEGER DEFAULT 0,				-- internal log level
LOGOPTS TEXT,
LOGSIPDISPSIZE INTEGER DEFAULT 2000,	-- number of SIP pcap lines to display
LOGSIPNUMFILES INTEGER DEFAULT 10,		-- number of SIP pcap spins to keep
LOGSIPFILESIZE INTEGER DEFAULT 20000,	-- SIP pcap max filesize (bytes)
MAXIN INTEGER DEFAULT 30,              -- maximum inbound calls
MAXOUT INTEGER DEFAULT 30,             -- maximum outbound calls
MYCOMMIT TEXT,                      -- commit outstanding
NATDEFAULT TEXT DEFAULT 'remote', 	-- V6 NAT defaiult local/remote
NATPARAMS TEXT DEFAULT 'force_rport,comedia', --V6 NAT default remote params
OPERATOR INTEGER DEFAULT 100,
PWDLEN INTEGER DEFAULT 12,				-- password length deprecated
RECFILEDLIM TEXT DEFAULT '_-_',     -- recordings filename delimiter
RECLIMIT TEXT,                      -- recording max size
RECMOUNT TEXT,                   	-- Recording folder mount command
RECQDITHER TEXT,                    -- dither (ms) on queuelog searches
RECQSEARCHLIM TEXT,                 -- search limit on queuelog
SESSIONTIMOUT INTEGER DEFAULT 600,  -- sessiontimeout (10minutes)
SENDEDOMAIN TEXT DEFAULT 'YES',  	-- Send public IP in SIP header YES/NO
SIPFLOOD TEXT DEFAULT 'NO',			-- detect SIP flood YES/NO
SIPDRIVER TEXT DEFAULT 'PJSIP',		-- SIP backend now PJSIP
SITENAME TEXT,                      -- Common name for this site 
STATICIPV4 TEXT DEFAULT NULL,		   -- Static IP to be started
SYSOP INTEGER DEFAULT 100,				-- system operator real extension
SYSPASS INTEGER DEFAULT 4444,			-- password for sysops **MOVED** BUT....
TLSPORT	INTEGER DEFAULT 5061,		-- TLS port (default 5061)
USEROTP TEXT DEFAULT NULL,			   -- V6 default OTP.  Seeded by the generator
VCL TEXT DEFAULT '1',			      -- V5 cloud enabled (1/0)
VOIPMAX INTEGER DEFAULT 30,			-- MAX outbound up calls 
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system'
);


/* master xref */

CREATE TABLE IF NOT EXISTS master_xref (
id TEXT PRIMARY KEY,
pkey TEXT,
cluster TEXT DEFAULT 'default',
relation TEXT
);

CREATE INDEX IF NOT EXISTS idx_xref_cluster ON master_xref (cluster);
CREATE INDEX IF NOT EXISTS idx_xref_relation ON master_xref (relation);

CREATE TABLE IF NOT EXISTS master_audit (
pkey integer PRIMARY KEY,
act TEXT,
owner TEXT,
relation TEXT,
tstamp datetime
);

/* messages table */
CREATE TABLE IF NOT EXISTS tt_help_core (
pkey TEXT PRIMARY KEY,
displayname TEXT,
htext TEXT,
-- name is deprecated and will be dropped in a near release use cname instead
name TEXT,
cname TEXT,                            -- common name
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system'
);


/* audit triggers */

CREATE TRIGGER IF NOT EXISTS agent_insert AFTER INSERT ON agent
BEGIN
   UPDATE agent set z_created=datetime('now'), z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('INSERT', new.pkey, 'agent', datetime('now'));   
END;
CREATE TRIGGER IF NOT EXISTS agent_update AFTER UPDATE ON agent
BEGIN
   UPDATE agent set z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('UPDATE', new.pkey, 'agent', datetime('now'));
END;
CREATE TRIGGER IF NOT EXISTS agent_delete AFTER DELETE ON agent
BEGIN
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('DELETE', old.pkey, 'agent', datetime('now'));
END;

CREATE TRIGGER IF NOT EXISTS appl_insert AFTER INSERT ON appl
BEGIN
   UPDATE appl set z_created=datetime('now'), z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('INSERT', new.pkey, 'appl', datetime('now'));   
END;
CREATE TRIGGER IF NOT EXISTS appl_update AFTER UPDATE ON appl
BEGIN
   UPDATE appl set z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('UPDATE', new.pkey, 'appl', datetime('now'));
END;
CREATE TRIGGER IF NOT EXISTS appl_delete AFTER DELETE ON appl
BEGIN
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('DELETE', old.pkey, 'appl', datetime('now'));
END;

CREATE TRIGGER IF NOT EXISTS COS_insert AFTER INSERT ON COS
BEGIN
   UPDATE COS set z_created=datetime('now'), z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('INSERT', new.pkey, 'COS', datetime('now'));   
END;
CREATE TRIGGER IF NOT EXISTS COS_update AFTER UPDATE ON COS
BEGIN
   UPDATE COS set z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('UPDATE', new.pkey, 'COS', datetime('now'));
END;
CREATE TRIGGER IF NOT EXISTS COS_delete AFTER DELETE ON COS
BEGIN
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('DELETE', old.pkey, 'COS', datetime('now'));
END;

CREATE TRIGGER IF NOT EXISTS Cluster_insert AFTER INSERT ON Cluster
BEGIN
   UPDATE Cluster set z_created=datetime('now'), z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('INSERT', new.pkey, 'Cluster', datetime('now'));   
END;
CREATE TRIGGER IF NOT EXISTS Cluster_update AFTER UPDATE ON Cluster
BEGIN
   UPDATE Cluster set z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('UPDATE', new.pkey, 'Cluster', datetime('now'));
END;
CREATE TRIGGER IF NOT EXISTS Cluster_delete AFTER DELETE ON Cluster
BEGIN
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('DELETE', old.pkey, 'Cluster', datetime('now'));
END;

CREATE TRIGGER IF NOT EXISTS Greeting_insert AFTER INSERT ON Greeting
BEGIN
   UPDATE Greeting set z_created=datetime('now'), z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('INSERT', new.pkey, 'Greeting', datetime('now'));   
END;
CREATE TRIGGER IF NOT EXISTS Greeting_update AFTER UPDATE ON Greeting
BEGIN
   UPDATE Greeting set z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('UPDATE', new.pkey, 'Greeting', datetime('now'));
END;
CREATE TRIGGER IF NOT EXISTS Greeting_delete AFTER DELETE ON Greeting
BEGIN
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('DELETE', old.pkey, 'Greeting', datetime('now'));
END;

CREATE TRIGGER IF NOT EXISTS Holidy_insert AFTER INSERT ON Holiday
BEGIN
   UPDATE Holiday set z_created=datetime('now'), z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('INSERT', new.pkey, 'Holiday', datetime('now'));   
END;
CREATE TRIGGER IF NOT EXISTS Holiday_update AFTER UPDATE ON Holiday
BEGIN
   UPDATE Holiday set z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('UPDATE', new.pkey, 'Holiday', datetime('now'));
END;
CREATE TRIGGER IF NOT EXISTS Holiday_delete AFTER DELETE ON Holiday
BEGIN
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('DELETE', old.pkey, 'Holiday', datetime('now'));
END;

CREATE TRIGGER IF NOT EXISTS IPphone_insert AFTER INSERT ON IPphone
BEGIN
   UPDATE IPphone set z_created=datetime('now'), z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('INSERT', new.pkey, 'IPphone', datetime('now'));   
END;
CREATE TRIGGER IF NOT EXISTS IPphone_update AFTER UPDATE ON IPphone
BEGIN
   UPDATE IPphone set z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('UPDATE', new.pkey, 'IPphone', datetime('now'));
END;
CREATE TRIGGER IF NOT EXISTS IPphone_delete AFTER DELETE ON IPphone
BEGIN
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('DELETE', old.pkey, 'IPphone', datetime('now'));
END;

CREATE TRIGGER IF NOT EXISTS Queue_insert AFTER INSERT ON Queue
BEGIN
   UPDATE Queue set z_created=datetime('now'), z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('INSERT', new.pkey, 'Queue', datetime('now'));   
END;
CREATE TRIGGER IF NOT EXISTS Queue_update AFTER UPDATE ON Queue
BEGIN
   UPDATE Queue set z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('UPDATE', new.pkey, 'Queue', datetime('now'));
END;
CREATE TRIGGER IF NOT EXISTS Queue_delete AFTER DELETE ON Queue
BEGIN
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('DELETE', old.pkey, 'Queue', datetime('now'));
END;

CREATE TRIGGER IF NOT EXISTS Route_insert AFTER INSERT ON Route
BEGIN
   UPDATE Route set z_created=datetime('now'), z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('INSERT', new.pkey, 'Route', datetime('now'));   
END;
CREATE TRIGGER IF NOT EXISTS Route_update AFTER UPDATE ON Route
BEGIN
   UPDATE Route set z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('UPDATE', new.pkey, 'Route', datetime('now'));
END;
CREATE TRIGGER IF NOT EXISTS Route_delete AFTER DELETE ON Route
BEGIN
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('DELETE', old.pkey, 'Route', datetime('now'));
END;

CREATE TRIGGER IF NOT EXISTS dateseg_insert AFTER INSERT ON dateseg
BEGIN
   UPDATE dateseg set z_created=datetime('now'), z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('INSERT', new.pkey, 'dateseg', datetime('now'));   
END;
CREATE TRIGGER IF NOT EXISTS dateseg_update AFTER UPDATE ON dateseg
BEGIN
   UPDATE dateseg set z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('UPDATE', new.pkey, 'dateseg', datetime('now'));
END;
CREATE TRIGGER IF NOT EXISTS dateseg_delete AFTER DELETE ON dateseg
BEGIN
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('DELETE', old.pkey, 'dateseg', datetime('now'));
END;

CREATE TRIGGER IF NOT EXISTS globals_insert AFTER INSERT ON globals
BEGIN
   UPDATE globals set z_created=datetime('now'), z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('INSERT', new.pkey, 'globals', datetime('now'));   
END;
CREATE TRIGGER IF NOT EXISTS globals_update AFTER UPDATE ON globals
BEGIN
   UPDATE globals set z_updated=datetime('now') where pkey=new.pkey;
   
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('UPDATE', new.pkey, 'globals', datetime('now'));
   
END;
CREATE TRIGGER IF NOT EXISTS globals_delete AFTER DELETE ON globals
BEGIN
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('DELETE', old.pkey, 'globals', datetime('now'));
END;

CREATE TRIGGER IF NOT EXISTS ivrmenu_insert AFTER INSERT ON ivrmenu
BEGIN
   UPDATE ivrmenu set z_created=datetime('now'), z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('INSERT', new.pkey, 'ivrmenu', datetime('now'));   
END;
CREATE TRIGGER IF NOT EXISTS ivrmenu_update AFTER UPDATE ON ivrmenu
BEGIN
   UPDATE ivrmenu set z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('UPDATE', new.pkey, 'ivrmenu', datetime('now'));
END;
CREATE TRIGGER IF NOT EXISTS ivrmenu_delete AFTER DELETE ON ivrmenu
BEGIN
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('DELETE', old.pkey, 'ivrmenu', datetime('now'));
END;

CREATE TRIGGER IF NOT EXISTS lineIO_insert AFTER INSERT ON lineIO
BEGIN
   UPDATE lineIO set z_created=datetime('now'), z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('INSERT', new.pkey, 'lineIO', datetime('now'));   
END;
CREATE TRIGGER IF NOT EXISTS lineIO_update AFTER UPDATE ON lineIO
BEGIN
   UPDATE lineIO set z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('UPDATE', new.pkey, 'lineIO', datetime('now'));
END;
CREATE TRIGGER IF NOT EXISTS lineIO_delete AFTER DELETE ON lineIO
BEGIN
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('DELETE', old.pkey, 'lineIO', datetime('now'));
END;

CREATE TRIGGER IF NOT EXISTS meetme_insert AFTER INSERT ON meetme
BEGIN
   UPDATE meetme set z_created=datetime('now'), z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('INSERT', new.pkey, 'meetme', datetime('now'));   
END;
CREATE TRIGGER IF NOT EXISTS meetme_update AFTER UPDATE ON meetme
BEGIN
   UPDATE meetme set z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('UPDATE', new.pkey, 'meetme', datetime('now'));
END;
CREATE TRIGGER IF NOT EXISTS meetme_delete AFTER DELETE ON meetme
BEGIN
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('DELETE', old.pkey, 'meetme', datetime('now'));
END;

CREATE TRIGGER IF NOT EXISTS speed_insert AFTER INSERT ON speed
BEGIN
   UPDATE speed set z_created=datetime('now'), z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('INSERT', new.pkey, 'speed', datetime('now'));   
END;
CREATE TRIGGER IF NOT EXISTS speed_update AFTER UPDATE ON speed
BEGIN
   UPDATE speed set z_updated=datetime('now') where pkey=new.pkey;
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('UPDATE', new.pkey, 'speed', datetime('now'));
END;
CREATE TRIGGER IF NOT EXISTS speed_delete AFTER DELETE ON speed
BEGIN
   INSERT INTO master_audit(act,owner,relation,tstamp) VALUES ('DELETE', old.pkey, 'speed', datetime('now'));
END;

/* system xref triggers */

CREATE TRIGGER IF NOT EXISTS agent_xref_insert AFTER INSERT ON agent
BEGIN
	INSERT INTO master_xref(pkey, cluster, relation) VALUES (new.pkey, new.cluster, 'agent');
END;
CREATE TRIGGER IF NOT EXISTS agent_xref_delete AFTER DELETE ON agent
BEGIN
   DELETE from master_xref WHERE pkey=old.pkey AND cluster=old.cluster AND relation='agent'; 
END;
CREATE TRIGGER IF NOT EXISTS agent_update_key AFTER UPDATE OF pkey ON agent
BEGIN
   UPDATE master_xref set pkey=new.pkey,cluster=new.cluster where pkey=old.pkey AND cluster=old.cluster AND relation='agent';
END;

CREATE TRIGGER IF NOT EXISTS appl_xref_insert AFTER INSERT ON appl
BEGIN
	INSERT INTO master_xref(pkey, cluster, relation) VALUES (new.pkey, new.cluster, 'appl');
END;
CREATE TRIGGER IF NOT EXISTS appl_xref_delete AFTER DELETE ON appl
BEGIN
   DELETE from master_xref WHERE pkey=old.pkey AND cluster=old.cluster AND relation='appl'; 
END;
CREATE TRIGGER IF NOT EXISTS appl_update_key AFTER UPDATE OF pkey ON appl
BEGIN
   UPDATE master_xref set pkey=new.pkey where pkey=old.pkey AND cluster=old.cluster AND relation='appl';
END;

CREATE TRIGGER IF NOT EXISTS COS_xref_insert AFTER INSERT ON COS
BEGIN
	INSERT INTO master_xref(pkey, relation) VALUES (new.pkey, 'COS');
END;
CREATE TRIGGER IF NOT EXISTS COS_xref_delete AFTER DELETE ON COS
BEGIN
   DELETE from master_xref WHERE pkey=old.pkey AND relation='COS'; 
END;
CREATE TRIGGER IF NOT EXISTS COS_update_key AFTER UPDATE OF pkey ON COS
BEGIN
   UPDATE master_xref set pkey=new.pkey where pkey=old.pkey AND relation='COS';
END;

CREATE TRIGGER IF NOT EXISTS Cluster_xref_insert AFTER INSERT ON Cluster
BEGIN
	INSERT INTO master_xref(pkey, relation) VALUES (new.pkey, 'Cluster');
END;
CREATE TRIGGER IF NOT EXISTS Cluster_xref_delete AFTER DELETE ON Cluster
BEGIN
   DELETE from master_xref WHERE pkey=old.pkey AND relation='Cluster'; 
END;
CREATE TRIGGER IF NOT EXISTS Cluster_update_key AFTER UPDATE OF pkey ON Cluster
BEGIN
   UPDATE master_xref set pkey=new.pkey where pkey=old.pkey AND relation='Cluster';
END;

CREATE TRIGGER IF NOT EXISTS Greeting_xref_insert AFTER INSERT ON Greeting
BEGIN
	INSERT INTO master_xref(pkey, cluster, relation) VALUES (new.pkey, new.cluster, 'Greeting');
END;
CREATE TRIGGER IF NOT EXISTS Greeting_xref_delete AFTER DELETE ON Greeting
BEGIN
   DELETE from master_xref WHERE pkey=old.pkey AND cluster=old.cluster AND relation='Greeting'; 
END;
CREATE TRIGGER IF NOT EXISTS Greeting_update_key AFTER UPDATE OF pkey ON Greeting
BEGIN
   UPDATE master_xref set pkey=new.pkey where pkey=old.pkey AND cluster=old.cluster AND relation='Greeting';
END;

CREATE TRIGGER IF NOT EXISTS IPphone_xref_insert AFTER INSERT ON IPphone
BEGIN
	INSERT INTO master_xref(pkey, cluster, relation) VALUES (new.pkey, new.cluster, 'IPphone');
END;
CREATE TRIGGER IF NOT EXISTS IPphone_xref_delete AFTER DELETE ON IPphone
BEGIN
   DELETE from master_xref WHERE pkey=old.pkey AND cluster=old.cluster AND relation='IPphone'; 
END;
CREATE TRIGGER IF NOT EXISTS IPphone_update_key AFTER UPDATE OF pkey ON IPphone
BEGIN
   UPDATE master_xref set pkey=new.pkey where pkey=old.pkey AND cluster=old.cluster AND relation='IPphone';
END;

CREATE TRIGGER IF NOT EXISTS Queue_xref_insert AFTER INSERT ON Queue
BEGIN
	INSERT INTO master_xref(pkey, cluster, relation) VALUES (new.pkey, new.cluster, 'Queue');
END;
CREATE TRIGGER IF NOT EXISTS Queue_xref_delete AFTER DELETE ON Queue
BEGIN
   DELETE from master_xref WHERE pkey=old.pkey AND cluster=old.cluster AND relation='Queue'; 
END;
CREATE TRIGGER IF NOT EXISTS Queue_update_key AFTER UPDATE OF pkey ON Queue
BEGIN
   UPDATE master_xref set pkey=new.pkey where pkey=old.pkey AND cluster=old.cluster AND relation='Queue';
END;

CREATE TRIGGER IF NOT EXISTS Route_xref_insert AFTER INSERT ON Route
BEGIN
	INSERT INTO master_xref(pkey, cluster, relation) VALUES (new.pkey, new.cluster, 'Route');
END;
CREATE TRIGGER IF NOT EXISTS Route_xref_delete AFTER DELETE ON Route
BEGIN
   DELETE from master_xref WHERE pkey=old.pkey AND cluster=old.cluster AND relation='Route'; 
END;
CREATE TRIGGER IF NOT EXISTS Route_update_key AFTER UPDATE OF pkey ON Route
BEGIN
   UPDATE master_xref set pkey=new.pkey where pkey=old.pkey AND cluster=old.cluster AND relation='Route';
END;

CREATE TRIGGER IF NOT EXISTS ivrmenu_xref_insert AFTER INSERT ON ivrmenu
BEGIN
	INSERT INTO master_xref(pkey, cluster, relation) VALUES (new.pkey, new.cluster, 'ivrmenu');
END;
CREATE TRIGGER IF NOT EXISTS ivrmenu_xref_delete AFTER DELETE ON ivrmenu
BEGIN
   DELETE from master_xref WHERE pkey=old.pkey AND cluster=old.cluster AND relation='ivrmenu'; 
END;
CREATE TRIGGER IF NOT EXISTS ivrmenu_update_key AFTER UPDATE OF pkey ON ivrmenu
BEGIN
   UPDATE master_xref set pkey=new.pkey where pkey=old.pkey AND cluster=old.cluster AND relation='ivrmenu';
END;

CREATE TRIGGER IF NOT EXISTS lineIO_xref_insert AFTER INSERT ON lineIO
BEGIN
	INSERT INTO master_xref(pkey, cluster, relation) VALUES (new.pkey, new.cluster, 'lineIO');
END;
CREATE TRIGGER IF NOT EXISTS lineIO_xref_delete AFTER DELETE ON lineIO
BEGIN
   DELETE from master_xref WHERE pkey=old.pkey AND cluster=old.cluster AND relation='lineIO'; 
END;
CREATE TRIGGER IF NOT EXISTS lineIO_update_key AFTER UPDATE OF pkey ON lineIO
BEGIN
   UPDATE master_xref set pkey=new.pkey where pkey=old.pkey AND cluster=old.cluster AND relation='lineIO';
END;

CREATE TRIGGER IF NOT EXISTS meetme_xref_insert AFTER INSERT ON meetme
BEGIN
	INSERT INTO master_xref(pkey, cluster, relation) VALUES (new.pkey, new.cluster, 'meetme');
END;
CREATE TRIGGER IF NOT EXISTS meetme_xref_delete AFTER DELETE ON meetme
BEGIN
   DELETE from master_xref WHERE pkey=old.pkey AND cluster=old.cluster AND relation='meetme'; 
END;
CREATE TRIGGER IF NOT EXISTS meetme_update_key AFTER UPDATE OF pkey ON meetme
BEGIN
   UPDATE master_xref set pkey=new.pkey where pkey=old.pkey AND cluster=old.cluster AND relation='meetme';
END;

CREATE TRIGGER IF NOT EXISTS speed_xref_insert AFTER INSERT ON speed
BEGIN
	INSERT INTO master_xref(pkey, cluster, relation) VALUES (new.pkey, new.cluster, 'speed');
END;
CREATE TRIGGER IF NOT EXISTS speed_xref_delete AFTER DELETE ON speed
BEGIN
   DELETE from master_xref WHERE pkey=old.pkey AND cluster=old.cluster AND relation='speed'; 
END;
CREATE TRIGGER IF NOT EXISTS speed_update_key AFTER UPDATE OF pkey ON speed
BEGIN
   UPDATE master_xref set pkey=new.pkey where pkey=old.pkey AND cluster=old.cluster AND relation='speed';
END;

COMMIT;

